# frozen_string_literal: true

Flipflop.configure do
  feature :mint_doi,
          default: false,
          description: "Shows admins a 'Mint DOI' button on work pages, which registers a DOI with DataCite."
end
