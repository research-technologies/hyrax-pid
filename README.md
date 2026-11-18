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

It's a Rails engine for Hyrax 5. It plugs into Hyrax's own identifier framework
(`Hyrax::Identifier::Dispatcher` / `Hyrax.config.identifier_registrars`) under
the `:doi` key, alongside any other registrars, and adds an admin-only
"Mint DOI" button that can be switched on and off per tenant.

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

### Set up the database and encryption keys

The engine runs its own migration (a `hyrax_pid_services` table) as part of
`bin/rails db:migrate`; in Hyku that creates it in every tenant.

Service passwords are stored with Rails' Active Record encryption, which needs
keys. Generate them with `bin/rails db:encryption:init`, then either put them in
your Rails credentials as that command suggests, or set them as environment
variables:

```
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
```

Keep the keys safe and the same across deploys: if they change, stored
credentials can't be read and have to be entered again.

### Enter credentials

Admins enter each service's credentials under *Configuration → PID services* in
the dashboard (`/pid/admin/services`). In Hyku these are per tenant. New
settings default to DataCite's test system; untick *sandbox* to mint real DOIs.

### Map your metadata

Create `config/initializers/hyrax_pid.rb`:

```ruby
Rails.application.config.to_prepare do
  Hyrax::Pid.configure do |config|
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

    # Optional: replace the HTTP client, e.g. with a fake for demos and tests.
    # config.data_cite.client = MyFakeClient.new
  end
end
```

`:doi` resolves to a DataCite minter built from the current tenant's saved
settings each time it's requested.

### Store the DOI on works

Works need a single-valued `doi` attribute. With flexible metadata, add a `doi`
property to your M3 profile; otherwise add one to your work models.

### Add the "Mint DOI" button

The engine mounts itself at `/pid`, so no route changes are needed. Render the
button wherever you want it, typically in an override of
`app/views/hyrax/base/_show_actions.html.erb`:

```erb
<%= render 'hyrax/pid/mint_button', presenter: presenter %>
```

The button only appears for admins, once DataCite has been configured, and once the **Mint DOI** feature
(`mint_doi`, off by default) is turned on in the dashboard's Features page
(`/admin/features`). In Hyku
this is per tenant. It also stays hidden while Hyrax's read-only mode is on.

The feature switch is not access control: Flipflop lets anyone force a feature
on for themselves with a cookie. Admin rights are what restrict minting.

Minting sends the work's page on the current host as the DOI's landing page
`url`, which DataCite needs before a DOI can be made findable.

### Mint from code

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

Or through Hyrax's identifier framework, which mints (or updates, if the work
already has a DOI) and saves the work in one call:

```ruby
Hyrax::Identifier::Dispatcher
  .for(:doi, landing_page_url: ->(work) { main_app.polymorphic_url(work) })
  .assign_for!(object: work, attribute: :doi)
```



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/research-technologies/hyrax-pid.
