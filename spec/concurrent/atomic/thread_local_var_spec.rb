require 'spec_helper'
require 'rbconfig'

module Concurrent

  require 'concurrent/atomic/thread_local_var'

  describe ThreadLocalVar do

    subject { ThreadLocalVar.new }

    context '#initialize' do

      it 'can set an initial value' do
        v = ThreadLocalVar.new(14)
        expect(v.value).to eq 14
      end

      it 'sets nil as a default initial value' do
        v = ThreadLocalVar.new
        expect(v.value).to be_nil
      end

      it 'sets the same initial value for all threads' do
        v  = ThreadLocalVar.new(14)
        t1 = Thread.new { v.value }
        t2 = Thread.new { v.value }
        expect(t1.value).to eq 14
        expect(t2.value).to eq 14
      end

      if jruby?
        it 'uses ThreadLocalJavaStorage' do
          expect(subject.class.ancestors).to include(Concurrent::AbstractThreadLocalVar::ThreadLocalJavaStorage)
        end
      else
        it 'uses ThreadLocalNewStorage' do
          expect(subject.class.ancestors).to include(Concurrent::AbstractThreadLocalVar::ThreadLocalRubyStorage)
        end
      end
    end

    unless jruby?
      context 'GC' do
        it 'does not leave values behind when bind is used' do
          var = ThreadLocalVar.new(0)
          10.times.map do |i|
            Thread.new { var.bind(i) { var.value } }
          end.each(&:join)
          var.value = 0
          expect(var.instance_variable_get(:@storage).keys.size).to be == 1
        end

        it 'does not leave values behind when bind is not used' do
          if rbx?
            pending('fails on Rbx, possibly due to test dependency on GC')
          end
          tries = Array.new(10) do
            var = ThreadLocalVar.new(0)
            10.times.map do |i|
              Thread.new { var.value = i; var.value }
            end.each(&:join)
            var.value = 0
            GC.start
            var.instance_variable_get(:@storage).keys.size == 1
          end
          expect(tries.any?).to be_truthy
        end
      end
    end

    context '#value' do

      it 'returns the current value' do
        v = ThreadLocalVar.new(14)
        expect(v.value).to eq 14
      end

      it 'returns the value after modification' do
        v       = ThreadLocalVar.new(14)
        v.value = 2
        expect(v.value).to eq 2
      end

    end

    context '#value=' do

      it 'sets a new value' do
        v       = ThreadLocalVar.new(14)
        v.value = 2
        expect(v.value).to eq 2
      end

      it 'returns the new value' do
        v = ThreadLocalVar.new(14)
        expect(v.value = 2).to eq 2
      end

      it 'does not modify the initial value for other threads' do
        v       = ThreadLocalVar.new(14)
        v.value = 2
        t       = Thread.new { v.value }
        expect(t.value).to eq 14
      end

      it 'does not modify the value for other threads' do
        v       = ThreadLocalVar.new(14)
        v.value = 2

        b1 = CountDownLatch.new(2)
        b2 = CountDownLatch.new(2)

        t1 = Thread.new do
          b1.count_down
          b1.wait
          v.value = 1
          b2.count_down
          b2.wait
          v.value
        end

        t2 = Thread.new do
          b1.count_down
          b1.wait
          v.value = 2
          b2.count_down
          b2.wait
          v.value
        end

        expect(t1.value).to eq 1
        expect(t2.value).to eq 2
      end

    end

  end

end
