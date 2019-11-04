# frozen_string_literal: true

module ElasticAPM
  # @api private
  module Spies
    # @api private
    class SneakersSpy
      def install
        Sneakers.middleware.use(Middleware, nil)
      end
      # @api private
      class Middleware
        def initialize(app, *args)
          @app = app
          @args = args
        end

        def call(deserialized_msg, delivery_info, metadata, handler)
          transaction = ElasticAPM.start_transaction(delivery_info.consumer.queue.name, 'Sneakers')
          ElasticAPM.set_label(:routing_key, delivery_info.routing_key)
          @app.call(deserialized_msg, delivery_info, metadata, handler)
          transaction.done :success if transaction
        rescue ::Exception => e
          ElasticAPM.report(e, handled: false)
          transaction.done :error if transaction
          raise
        ensure
          ElasticAPM.end_transaction
        end
      end
    end
    register 'Sneakers', 'sneakers', SneakersSpy.new
  end
end
