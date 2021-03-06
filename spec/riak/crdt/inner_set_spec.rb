require 'spec_helper'
require_relative 'shared_examples'

describe Riak::Crdt::InnerSet do
  let(:parent){ double 'parent' }
  let(:set_name){ 'set name' }
  subject do
    described_class.new(parent, []).tap do |s|
      s.name = set_name
    end
  end

  include_examples 'Set CRDT'

  it 'sends additions to the parent' do
    expect(parent).to receive(:operate) do |name, op|
      expect(name).to eq set_name
      expect(op.type).to eq :set
      expect(op.value).to eq add: 'el'
    end

    subject.add 'el'

    expect(parent).to receive(:operate) do |name, op|
      expect(name).to eq set_name
      expect(op.type).to eq :set
      expect(op.value).to eq remove: 'el2'
    end
    allow(parent).to receive(:context?).and_return(true)

    subject.remove 'el2'
  end
end
