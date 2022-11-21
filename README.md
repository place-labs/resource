# PlaceOS Resource

[![CI](https://github.com/place-labs/resource/actions/workflows/ci.yml/badge.svg)](https://github.com/place-labs/resource/actions/workflows/ci.yml)

Abstraction over [PgORM](https://github.com/spider-gazelle/pg-orm) changefeeds

## Implementation

`PlaceOS::Resource(T)` is a layer over `PgORM` models, providing an abstract interface to a table's changefeed.

## `abstract def process_resource(action : Action, resource : T)`

`process_resource(action : Action, resource : T)` is the only abstract method one must implement.
On startup, the entire table is iterated asynchronously, yielding `:created` events for each model.

After the initial pass, `Action::Created`, `Action::Deleted`, and `Action::Updated` events on the table are processed as they are received.

### `Action::Updated`

The model received with a `:updated` event has the changes applied in the form of standard [`active-model`](https://github.com/spider-gazelle/active-model) attribute changes information.


### `def on_reconnect`

A non-abstract def. In its stock form, `on_reconnect` is a noop.

This method can be overwritten in inheriting classes to perform actions after a changefeed is recovered.

## Contributing

1. [Fork it](https://github.com/place-labs/resource/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Caspian Baska](https://github.com/caspiano) - creator and maintainer
