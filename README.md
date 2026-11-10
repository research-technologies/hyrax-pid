# Hyrax::Pid

Mint and manage persistent identifiers (PIDs) for works in a
[Hyrax](https://github.com/samvera/hyrax) or [Hyku](https://github.com/samvera/hyku)
application.

`hyrax-pid` separates three elements of PID minting:

- **Minters** — thin adapters for identifier service's API. Each implements
  the same small interface (`mint`, `update`, `find`, `identifier_type`) and
  returns a plain `Hyrax::Pid::Identifier` value object, so callers never deal
  with a provider's raw response. A DataCite DOI minter is included;
  adapters for other services (Crossref, RAiD, …) may follow.
- **Metadata mapping** — a configurable mapping from your work's attributes to
  the payload the service expects. Each field can be a symbol, 
  callable, or literal, so it works with both fixed and flexible (M3) metadata
  schemas without hardcoding attribute names. Required fields fail loudly if
  they can't be resolved; optional ones are simply omitted.
- **Registry and configuration** — `Hyrax::Pid::Registry` maps a key such as
  `:doi` to a lazily-built, configured minter, so credentials and sandbox vs.
  production settings are resolved at call time, not at load time.

The core has no runtime dependencies and no knowledge of Hyrax. An optional
`Hyrax::Pid::Registrar` bridges into Hyrax's own identifier framework
(`Hyrax::Identifier::Dispatcher` / `Hyrax.config.identifier_registrars`), so
it can replace or sit beside existing registrars with no further glue.

This is deliberately smaller than [hyrax-doi](https://github.com/samvera-labs/hyrax-doi):
no actors, no Bolognese crosswalk, no assumptions about which attributes your
works have. You tell it where the metadata comes from; it tells the service.

## Installation

 In your
application's `Gemfile`:

```ruby
gem "hyrax-pid", github: "research-technologies/hyrax-pid"
```

and `bundle install`

Hyku Knapsack: Add line to a file under bundler.d/ (e.g. bundler.d/hyrax_pid.rb), for bundler-inject to pick up.

## Usage

### Configure a minter

Create config/initializers/hyrax_pid.rb:

```ruby
Rails.application.config.to_prepare do
  Hyrax::Pid.configure do |config|
    config.data_cite.prefix   = ENV.fetch("DATACITE_PREFIX")
    config.data_cite.username = ENV.fetch("DATACITE_USERNAME")
    config.data_cite.password = ENV.fetch("DATACITE_PASSWORD")
    config.data_cite.sandbox  = !Rails.env.production?

    # How to read DataCite's required fields off a work. A Symbol is called as
    # a method on the work, a callable is called with the work, anything else
    # is used as a literal.
    config.data_cite.field_mapping = {
      title: :title,
      creator: :creator,
      publisher: "My Institution",
      publication_year: ->(work) { Array(work.date_created).first.to_s[/\d{4}/] },
      resource_type_general: "Other"
    }
  end
end
```

`:doi` is registered automatically and resolves to a DataCite minter built from
this configuration each time it's requested.


### Mint

```ruby
work     = Hyrax.query_service.find_by(id: id)
metadata = Hyrax::Pid.configuration.data_cite.metadata_mapper.build(work)
doi      = Hyrax::Pid::Registry.minter_for(:doi).mint(metadata: metadata)

doi.value  # => "10.1234/abcd-efgh"
doi.state  # => :draft
```

<!--
DOIs are minted as drafts. Once the record has a landing page URL and complete
metadata, `minter.publish(identifier: doi)` makes it findable.
-->

Optional: plug into Hyrax's identifier framework

To use Hyrax::Identifier::Dispatcher (as hyrax-doi and other registrars do),
register the bridge in the same initializer:

```ruby
Rails.application.config.to_prepare do
  require "hyrax/pid/registrar"
  Hyrax.config.identifier_registrars = { doi: Hyrax::Pid::Registrar }
end
```

Then minting-or-updating and persisting is one call:

```rub
Hyrax::Identifier::Dispatcher.for(:doi).assign_for!(object: work, attribute: :doi)
```

The work needs a doi attribute to store the result; add one to your model or
M3 profile if it doesn't exist.



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/research-technologies/hyrax-pid.
