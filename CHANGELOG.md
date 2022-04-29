## v2.3.0 (2022-01-19)

### Feat

- reconnect callback (#12)

## v2.2.0 (2021-10-15)

### Feat

- promise-3.0.0
- add `#startup_finished?`

### Fix

- retry if resource still open

## v2.0.5 (2021-07-30)

### Refactor

- lower log verbosity regarding event processing

## v2.0.4 (2021-07-15)

### Refactor

- less verbose message on `load_resource` finish

### Fix

- **rethinkdb-orm**: bump orm

## v2.0.3 (2021-07-08)

### Fix

- unwrap atomic

## v2.0.2 (2021-07-08)

### Fix

- serializable error

### Refactor

- use atomics
- use structs in favour of NamedTuples

## v1.2.1 (2021-04-13)

### Fix

- cause can be nillable

### Feat

- **error**: add `cause` to `ProcessingError`

### Perf

- allocate buffer the size of batches

## v1.0.4 (2020-08-20)

### Fix

- add Fiber.yield

## v1.0.3 (2020-08-18)

### Refactor

- ensure all event NamedTuples are identical

## v1.0.2 (2020-08-07)

### Fix

- retry changefeed

## v1.0.0 (2020-07-17)

### Feat

- v1.0.0
