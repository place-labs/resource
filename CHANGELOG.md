## v3.1.0 (2023-07-24)

### Feat

- load resources in order of creation

## v3.0.5 (2023-07-14)

### Fix

- **resource**: replaced change feed iterator with async closure

## v3.0.4 (2023-07-14)

### Fix

- **resource**: replaced change feed iterator with async closure

## v3.0.3 (2023-07-14)

### Fix

- **placeos-resource**: Fix missing change events

## v3.0.2 (2023-07-11)

### Fix

- add timeout to resource loading ([#19](https://github.com/place-labs/resource/pull/19))

## v3.0.1 (2023-05-08)

### Fix

- resource should hint at changes ([#18](https://github.com/place-labs/resource/pull/18))

## v3.0.0 (2023-03-16)

### Refactor

- migrate to postgresql ([#17](https://github.com/place-labs/resource/pull/17))

## v2.5.4 (2022-05-06)

### Refactor

- **telemetry**: instrument `process_resource` instead of `_process_resource`

## v2.5.3 (2022-05-05)

### Refactor

- rename `instrumentation` to `telemetry`

## v2.5.2 (2022-05-03)

### Fix

- remove telemetry require

## v2.5.1 (2022-05-03)

### Fix

- require instrumentation last

## v2.5.0 (2022-05-02)

### Feat

- **instrumentation**: trace `load_resources`

## v2.4.0 (2022-04-30)

### Feat

- **instrumentation**: add OpenTelemetry to `PlaceOS::Resource` ([#14](https://github.com/place-labs/resource/pull/14))

## v2.3.1 (2022-03-09)

## v2.3.0 (2022-01-19)

### Feat

- reconnect callback ([#12](https://github.com/place-labs/resource/pull/12))

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

### Fix

- **rethinkdb-orm**: bump orm

### Refactor

- less verbose message on `load_resource` finish

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

### Feat

- **error**: add `cause` to `ProcessingError`

### Fix

- cause can be nillable

### Perf

- allocate buffer the size of batches

## v1.0.6 (2021-02-23)

## v1.0.5 (2020-08-20)

## v1.0.4 (2020-08-20)

### Fix

- add Fiber.yield

## v1.0.3 (2020-08-18)

### Refactor

- ensure all event NamedTuples are identical

## v1.0.2 (2020-08-07)

### Fix

- retry changefeed

## v1.0.1 (2020-08-06)

## v1.0.0 (2020-07-17)

### Feat

- v1.0.0
