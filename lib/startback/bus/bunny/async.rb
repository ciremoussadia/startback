require 'bunny'
module Startback
  class Bus
    module Bunny
      #
      # Asynchronous implementation of the bus abstraction, on top of RabbitMQ
      # and using the 'bunny' gem (you need to include it in your Gemfile
      # yourself: it is NOT a startback official dependency).
      #
      # This bus implementation emits events by dumping them to RabbitMQ using
      # the event type as exchange name. Listeners may use the `processor`
      # parameter to specify the queue name ; otherwise a default "main" queue
      # is used.
      #
      # Examples:
      #
      #     # Connects to RabbitMQ using all default options
      #     #
      #     # Uses the STARTBACK_BUS_BUNNY_ASYNC_URL environment variable for
      #     # connection URL if present.
      #     Startback::Bus::Bunny::Async.new
      #
      #     # Connects to RabbitMQ using a specific URL
      #     Startback::Bus::Bunny::Async.new("amqp://rabbituser:rabbitpass@192.168.17.17")
      #     Startback::Bus::Bunny::Async.new(url: "amqp://rabbituser:rabbitpass@192.168.17.17")
      #
      #     # Connects to RabbitMQ using specific connection options. See Bunny's own
      #     # documentation
      #     Startback::Bus::Bunny::Async.new({
      #       connection_options: {
      #         host: "192.168.17.17"
      #       }
      #     })
      #
      class Async
        include Support::Robustness

        DEFAULT_OPTIONS = {
          # (optional) The URL to use for connecting to RabbitMQ.
          url: ENV['STARTBACK_BUS_BUNNY_ASYNC_URL'],

          # (optional) The options has to pass to ::Bunny constructor
          connection_options: nil,

          # (optional) The options to use for the emitter/listener fanout
          fanout_options: {},

          # (optional) The options to use for the listener queue
          queue_options: {},

          # (optional) Default event factory to use, if any
          event_factory: nil,

          # (optional) A default context to use for general logging
          context: nil
        }

        # Creates a bus instance, using the various options provided to
        # fine-tune behavior.
        def initialize(options = {})
          options = { url: options } if options.is_a?(String)
          @options = DEFAULT_OPTIONS.merge(options)
          retried = 0
          conn = options[:connection_options] || options[:url]
          try_max_times(10) do
            @bunny = ::Bunny.new(conn)
            @bunny.start
            @channel = @bunny.create_channel
            log(:info, {op: "#{self.class.name}#connect", op_data: conn}, options[:context])
          end
        end
        attr_reader :channel, :options

        def emit(event)
          stop_errors(self, "emit", event.context) do
            fanout = channel.fanout(event.type.to_s, fanout_options)
            fanout.publish(event.to_json)
          end
        end

        def listen(type, processor = nil, listener = nil, &bl)
          raise ArgumentError, "A listener must be provided" unless listener || bl
          fanout = channel.fanout(type.to_s, fanout_options)
          queue = channel.queue((processor || "main").to_s, queue_options)
          queue.bind(fanout)
          queue.subscribe do |delivery_info, properties, body|
            event = stop_errors(self, "listen") do
              factor_event(body)
            end
            stop_errors(self, "listen", event.context) do
              (listener || bl).call(event)
            end
          end
        end

      protected

        def fanout_options
          options[:fanout_options]
        end

        def queue_options
          options[:queue_options]
        end

        def factor_event(body)
          if options[:event_factory]
            options[:event_factory].call(body)
          else
            Event.json(body, options)
          end
        end

      end # class Async
    end # module Bunny
  end # class Bus
end # module Klaro
