# Unbound dns

## What can the formula do?

Gunbound up and running

## installation

Just add the hook it up like every other formula and do the needed

### Required salt master config:

```
file_roots:
  base:
    [ snip ]
    - {{ formulas_base_dir }}/crustated_identity/salt/

pillar_roots:
  base:
    [ snip ]
    - {{ formulas_base_dir }}/crustated_identity/pillar/
```

## cfgmgmt-template integration

if you are using our [cfgmgmt-template](https://github.com/darix/cfgmgmt-template) as a starting point the saltmaster you can simplify the setup with:

```
git submodule add https://github.com/darix/crustated_identity formulas/crustated_identity
ln -s /srv/cfgmgmt/formulas/crustated_identity/config/enable_crustated_identity.conf /etc/salt/master.d/
systemctl restart saltmaster
```

## How to use

Follow pillar.example for your pillar settings.

## License

[AGPL-3.0-only](https://spdx.org/licenses/AGPL-3.0-only.html)

[0]: https://build.opensuse.org/package/show/home:darix:apps/nftables-service