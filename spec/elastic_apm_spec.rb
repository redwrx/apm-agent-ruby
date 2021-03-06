# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticAPM do
  describe 'life cycle' do
    it 'starts and stops the agent' do
      ElasticAPM.start ElasticAPM::Config.new
      expect(ElasticAPM::Agent).to be_running

      ElasticAPM.stop
      expect(ElasticAPM::Agent).to_not be_running
    end
  end

  context 'when running', :mock_intake do
    before do
      ElasticAPM.start
    end

    let(:agent) { ElasticAPM.agent }

    describe '.log_ids' do
      context 'with no current_transaction' do
        it 'returns empty string' do
          expect(ElasticAPM.log_ids).to eq('')
        end
      end

      context 'with a current transaction' do
        it 'includes transaction and trace ids' do
          transaction = ElasticAPM.start_transaction 'Test'
          expect(ElasticAPM.log_ids).to eq(
            "transaction.id=#{transaction.id} trace.id=#{transaction.trace_id}"
          )
        end
      end

      context 'with a current_span' do
        it 'includes transaction, span and trace ids' do
          trans = ElasticAPM.start_transaction
          span = ElasticAPM.start_span 'Test'
          expect(ElasticAPM.log_ids).to eq(
            "transaction.id=#{trans.id} span.id=#{span.id} " \
              "trace.id=#{trans.trace_id}"
          )
        end
      end

      context 'when passed a block' do
        it 'yields each id' do
          transaction = ElasticAPM.start_transaction
          span = ElasticAPM.start_span 'Test'
          ElasticAPM.log_ids do |transaction_id, span_id, trace_id|
            expect(transaction_id).to eq(transaction.id)
            expect(span_id).to eq(span.id)
            expect(trace_id).to eq(transaction.trace_id)
          end
        end
      end
    end

    describe '.start_transaction' do
      it 'starts a transaction' do
        transaction = ElasticAPM.start_transaction 'Test'
        expect(transaction).to be_a ElasticAPM::Transaction
        expect(transaction.name).to eq 'Test'
      end
    end

    describe '.end_transaction', :intercept do
      it 'ends current transaction' do
        transaction = ElasticAPM.start_transaction 'Test'
        expect(ElasticAPM.current_transaction).to_not be_nil

        ElasticAPM.end_transaction
        expect(ElasticAPM.current_transaction).to be_nil
        expect(transaction).to be_stopped

        transaction, = @intercepted.transactions
        expect(transaction.name).to eq 'Test'
      end
    end

    describe '.with_transaction' do
      let(:placeholder) { Struct.new(:transaction).new }

      subject do
        ElasticAPM.with_transaction('Block test') do |transaction|
          placeholder.transaction = transaction

          'original result'
        end
      end

      it 'wraps block in transaction' do
        subject

        expect(placeholder.transaction).to be_a ElasticAPM::Transaction
        expect(placeholder.transaction.name).to eq 'Block test'
      end

      it { should eq 'original result' }
    end

    describe '.start_span' do
      it 'starts a span' do
        ElasticAPM.start_transaction

        span = ElasticAPM.start_span 'Test'
        expect(span).to be_a ElasticAPM::Span
        expect(span.name).to eq 'Test'
      end
    end

    describe '.end_span' do
      it 'ends current span' do
        ElasticAPM.start_transaction

        span = ElasticAPM.start_span 'Test'
        expect(ElasticAPM.current_span).to_not be_nil

        ElasticAPM.end_span
        expect(ElasticAPM.current_span).to be_nil
        expect(span).to be_stopped
      end
    end

    describe '.with_span' do
      let(:placeholder) { Struct.new(:spans).new([]) }

      before { ElasticAPM.start_transaction }

      subject do
        ElasticAPM.with_span('Block test') do |span1|
          placeholder.spans << span1

          ElasticAPM.with_span('All the way down') do |span2|
            placeholder.spans << span2

            'original result'
          end
        end
      end

      it 'wraps block in span' do
        subject

        expect(placeholder.spans.length).to be 2
        span1, span2 = placeholder.spans

        expect(span1.name).to eq 'Block test'
        expect(span2.name).to eq 'All the way down'
      end

      it 'includes stacktraces by default' do
        allow(agent.config).to receive(:span_frames_min_duration_us) { -1 }

        subject

        expect(placeholder.spans.length).to be 2
        expect(placeholder.spans.map(&:stacktrace))
          .to all(be_a(ElasticAPM::Stacktrace))
      end

      it { should eq 'original result' }
    end

    it { should delegate :current_transaction, to: agent }

    it do
      should delegate :report,
        to: agent, args: ['E', { context: nil, handled: nil }]
    end
    it do
      should delegate :report_message,
        to: agent, args: ['NOT OK', { backtrace: Array, context: nil }]
    end
    it { should delegate :set_label, to: agent, args: [nil, nil] }
    it { should delegate :set_custom_context, to: agent, args: [nil] }
    it { should delegate :set_user, to: agent, args: [nil] }

    describe '#add_filter' do
      it { should delegate :add_filter, to: agent, args: [nil, -> {}] }

      it 'needs either callback or block' do
        expect { subject.add_filter(:key) }.to raise_error(ArgumentError)

        expect do
          subject.add_filter(:key) { 'ok' }
        end.to_not raise_error
      end
    end

    after { ElasticAPM.stop }
  end

  context 'when not running' do
    it 'still yields block' do
      ran = false

      ElasticAPM.with_transaction { ran = true }

      expect(ran).to be true
    end
  end
end
