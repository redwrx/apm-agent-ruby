# frozen_string_literal: true

require 'net/http'

module ElasticAPM
  RSpec.describe 'Spy: NetHTTP', :intercept do
    after do
      ElasticAPM.stop
      WebMock.reset!
    end

    it 'spans http calls' do
      WebMock.stub_request(:get, %r{http://example.com/.*})
      ElasticAPM.start

      ElasticAPM.with_transaction 'Net::HTTP test' do
        Net::HTTP.start('example.com') do |http|
          http.get '/'
        end
      end

      span, = @intercepted.spans

      expect(span.name).to eq 'GET example.com'
    end

    it 'adds traceparent header' do
      req_stub =
        WebMock.stub_request(:get, %r{http://example.com/.*}).with do |req|
          header = req.headers['Elastic-Apm-Traceparent']
          expect(header).to_not be nil
          expect { TraceContext.parse(header) }.to_not raise_error
        end

      ElasticAPM.start

      ElasticAPM.with_transaction 'Net::HTTP test' do
        Net::HTTP.start('example.com') do |http|
          http.get '/'
        end
      end

      expect(req_stub).to have_been_requested
    end

    it 'adds traceparent header with no span' do
      req_stub = WebMock.stub_request(:get, %r{http://example.com/.*})

      ElasticAPM.start transaction_max_spans: 0

      ElasticAPM.with_transaction 'Net::HTTP test' do
        Net::HTTP.start('example.com') do |http|
          http.get '/'
        end
      end

      expect(req_stub).to have_been_requested
    end

    it 'can be disabled' do
      WebMock.stub_request(:any, %r{http://example.com/.*})
      ElasticAPM.start

      expect(ElasticAPM::Spies::NetHTTPSpy).to_not be_disabled

      ElasticAPM.with_transaction 'Net::HTTP test' do
        ElasticAPM::Spies::NetHTTPSpy.disable_in do
          Net::HTTP.start('example.com') do |http|
            http.get '/'
          end
        end

        Net::HTTP.start('example.com') do |http|
          http.post '/', 'a=1'
        end
      end

      expect(@intercepted.transactions.length).to be 1
      expect(@intercepted.spans.length).to be 1

      span, = @intercepted.spans
      expect(span.name).to eq 'POST example.com'
      expect(span.type).to eq 'ext'
      expect(span.subtype).to eq 'net_http'
      expect(span.action).to eq 'POST'

      ElasticAPM.stop
      WebMock.reset!
    end
  end
end
