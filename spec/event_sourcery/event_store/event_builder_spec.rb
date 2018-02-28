module EventSourcery
  module EventStore
    RSpec.describe EventBuilder do
      describe '#build' do
        let(:event_builder) { EventBuilder.new(event_type_serializer: EventSourcery.config.event_type_serializer) }

        describe 'upcasting' do
          before do
            stub_const('Foo', Class.new(EventSourcery::Event) do
              def self.upcast(event)
                body = event.body

                body['bar'] ||= 'baz'

                event.with(body: body)
              end
            end)
          end

          it 'upcasts the event' do
            event = event_builder.build(
              type: 'foo',
              body: {
                'foo' => 1,
              },
            )

            expect(event.class).to eq Foo
            expect(event.body).to eq(
              'foo' => 1,
              'bar' => 'baz',
            )
          end
        end
      end
    end
  end
end
