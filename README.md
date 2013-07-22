# MopedMapping

moped extension library to switch collection.

## Installation

Add this line to your application's Gemfile:

    gem 'moped_mapping'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install moped_mapping

## Usage

### Global switch

#### configuration

```
MopedMapping.enable
```

#### each action

```
MopedMapping.collection_map(@database_name,{"items" => "items@3" }) do
  # actually this document will be inserted into items@3
  session["items"].insert({some: "document"})
end
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

GPLv3

Copyright (C) 2013  Groovenauts, inc.
