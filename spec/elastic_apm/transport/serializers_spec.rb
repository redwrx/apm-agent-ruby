# frozen_string_literal: true

module ElasticAPM
  module Transport
    RSpec.describe Serializers do
      let(:config) { Config.new }
      subject { described_class.new(config) }

      it 'initializes with config' do
        expect(subject).to be_a Serializers::Container
        expect(subject.transaction).to be_a Serializers::TransactionSerializer
        expect(subject.span).to be_a Serializers::SpanSerializer
        expect(subject.error).to be_a Serializers::ErrorSerializer
        expect(subject.metricset).to be_a Serializers::MetricsetSerializer
        expect(subject.metadata).to be_a Serializers::MetadataSerializer
      end

      describe '#serialize' do
        it 'serializes known objects' do
          expect(subject.serialize(
                   Transaction.new(config: config)
                 )).to be_a Hash
          expect(subject.serialize(Span.new(name: 'Name',
                                            transaction_id: '',
                                            trace_context: TraceContext.new)))
            .to be_a Hash
          expect(subject.serialize(Error.new)).to be_a Hash
        end

        it 'explodes on unknown objects' do
          expect { subject.serialize(Object.new) }
            .to raise_error(Serializers::UnrecognizedResource)
        end
      end

      describe '#keyword_field' do
        class TruncateSerializer < Serializers::Serializer
          def serialize(obj)
            { test: keyword_field(obj[:test]) }
          end
        end

        it 'truncates values to 1024 chars' do
          obj = { test: 'X' * 2000 }
          thing = TruncateSerializer.new(Config.new).serialize(obj)
          expect(thing[:test]).to match(/X{1023}…/)
        end
      end

      describe '#keyword_object' do
        class TruncateSerializer < Serializers::Serializer
          def serialize(obj)
            keyword_object(obj)
          end
        end

        it 'truncates values to 1024 chars' do
          obj = { test: 'X' * 2000 }
          thing = TruncateSerializer.new(Config.new).serialize(obj)
          expect(thing[:test]).to match(/X{1023}…/)
        end
      end

      describe '#mixed_object' do
        class TruncateSerializer < Serializers::Serializer
          def serialize(obj)
            mixed_object(obj)
          end
        end

        it 'truncates strings to 1024 chars and leaves others unchanged' do
          obj = { string: 'X' * 2000,
                  bool: true,
                  numerical: 123 }
          thing = TruncateSerializer.new(Config.new).serialize(obj)
          expect(thing[:string]).to match(/X{1023}…/)
          expect(thing[:bool]).to match(true)
          expect(thing[:numerical]).to match(123)
        end
      end
    end
  end
end
