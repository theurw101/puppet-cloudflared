# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/cloudflared/cloudflare_api'

RSpec.describe PuppetX::Cloudflared::CloudflareAPI do
  let(:http) { instance_spy(Net::HTTP) }
  let(:requests) { [] }
  let(:response_bodies) { [] }
  let(:api) do
    described_class.new(
      api_token: 'test-api-token',
      account_id: '0123456789abcdef0123456789abcdef',
      api_base_url: 'https://api.example.test/client/v4',
      http_factory: ->(_uri) { http },
    )
  end

  before do
    response_bodies.replace([{ success: true, result: [] }.to_json])
    allow(http).to receive(:request) do |request|
      requests << request
      response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return(response_bodies.shift)
      response
    end
  end

  describe '#ensure_local_tunnel' do
    it 'returns an existing locally managed tunnel without creating another' do
      response_bodies.replace([{ success: true, result: [{ id: 'tunnel-uuid', name: 'website', config_src: 'local' }] }.to_json])

      expect(api.ensure_local_tunnel(name: 'website', tunnel_secret: secret)).to include('id' => 'tunnel-uuid')
      expect(http).to have_received(:request).once
      expect(requests.first).to be_a(Net::HTTP::Get)
      expect(requests.first['Authorization']).to eq('Bearer test-api-token')
      expect(requests.first.path).to include('name=website')
    end

    it 'creates a local tunnel when no matching tunnel exists' do
      created_tunnel = { 'id' => 'new-tunnel-uuid', 'name' => 'website', 'config_src' => 'local' }
      response_bodies.replace([
                                { success: true, result: [] }.to_json,
                                { success: true, result: created_tunnel }.to_json,
                              ])

      expect(api.ensure_local_tunnel(name: 'website', tunnel_secret: secret)).to eq(created_tunnel)
      expect(http).to have_received(:request).twice
      create_request = requests.last
      expect(create_request).to be_a(Net::HTTP::Post)
      expect(create_request['Authorization']).to eq('Bearer test-api-token')
      expect(JSON.parse(create_request.body)).to eq(
        'name' => 'website',
        'config_src' => 'local',
        'tunnel_secret' => secret,
      )
    end

    it 'rejects secrets shorter than 32 decoded bytes' do
      expect do
        api.ensure_local_tunnel(name: 'website', tunnel_secret: Base64.strict_encode64('short'))
      end.to raise_error(ArgumentError, %r{at least 32 bytes})
    end

    it 'rejects a matching remotely managed tunnel' do
      response_bodies.replace([{ success: true, result: [{ id: 'tunnel-uuid', name: 'website', config_src: 'cloudflare' }] }.to_json])

      expect do
        api.ensure_local_tunnel(name: 'website', tunnel_secret: secret)
      end.to raise_error(described_class::Error, %r{not locally managed})
    end
  end

  def secret
    Base64.strict_encode64('a' * 32)
  end
end
