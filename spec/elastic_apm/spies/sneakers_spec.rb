require 'sneakers'
require 'elastic_apm/spies/sneakers'
module ElasticAPM
  RSpec.describe 'Spy: Sneakers', :intercept do
    class Queue
      def name
        'q1'
      end
    end

    class Consumer
      def queue
        Queue.new
      end
    end

    class DeliveryInfo
      def routing_key
        'r1234'
      end
      def consumer
        Consumer.new
      end
    end

    class TestWorker
      include Sneakers::Worker
      from_queue 'q1',
                 ack: false
      def work(message)
      end
    end

    class TestErrorWorker
      include Sneakers::Worker
      from_queue 'q1',
                 ack: false
      def work(message)
        1/0
      end
    end

    before :all do
      Sneakers.configure
    end

    before { ElasticAPM.start }
    after { ElasticAPM.stop }

    it 'instruments job transaction' do
      worker = TestWorker.new
      worker.process_work(DeliveryInfo.new, nil, nil, nil)
      transaction, = @intercepted.transactions
      expect(transaction.name).to eq DeliveryInfo.new.consumer.queue.name
      label, = transaction.context.labels
      expect(label[:routing_key]).to eq DeliveryInfo.new.routing_key
      expect(transaction.type).to eq 'Sneakers'
      expect(transaction.result).to eq :success
    end

    it 'reports errors' do
      worker = TestErrorWorker.new
      worker.process_work(DeliveryInfo.new, nil, nil, nil)
      transaction, = @intercepted.transactions
      expect(transaction.name).to eq DeliveryInfo.new.consumer.queue.name
      label, = transaction.context.labels
      expect(label[:routing_key]).to eq DeliveryInfo.new.routing_key
      expect(transaction.type).to eq 'Sneakers'
      expect(transaction.result).to eq :error
      error, = @intercepted.errors
      expect(error.exception.type).to eq 'ZeroDivisionError'
    end
  end
end


