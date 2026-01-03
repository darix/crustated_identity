#!py
#
# boundedns
#
# Copyright (C) 2025   darix
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

from salt.exceptions import SaltConfigurationError, SaltRenderError
import logging
import ipaddress
import salt.serializers.tomlmod as tomlmod
log = logging.getLogger("crustated-identity")


def run():
  config = {}
  formula_pillar = __salt__['pillar.get']('kanidm', {})
  kanidm_server_packages = ["kanidm-server", "kanidm-clients"]
  kanidm_client_packages = ["kanidm-unixd-clients"]

  kanidm_server_pillar = __salt__['pillar.get']('kanidm:server', {})
  kanidm_client_pillar = __salt__['pillar.get']('kanidm:client', {})

  static_user_group = 'kanidmd'
  static_home_dir = '/var/lib/kanidmd'
  static_cache_dir = '/var/cache/kanidmd'
  static_drop_in_dir =  '/etc/systemd/system/kanidmd.service.d'
  static_drop_in_file = f'{static_drop_in_dir}/use_static_user.conf'

  server_default_config = {
    'version': '2',
    'bindaddress': '[::]:443',
    'db_path': '/var/lib/private/kanidm/kanidm.db',
    'tls_chain': '/var/lib/private/kanidm/chain.pem',
    'tls_key': '/var/lib/private/kanidm/key.pem',
    'domain': 'idm.example.com',
    'origin': 'https://idm.example.com',
    'online_backup': {
      'path': '/var/lib/private/kanidm/backups/',
      'schedule': '00 22 * * *',
      'compression': 'gzip'
    }
  }

  if kanidm_server_pillar.get('enabled', True):
    config["kanidm_server_packages"] = {
      "pkg.installed": [
        {'pkgs': kanidm_server_packages },
      ]
    }

    config_group = 'root'

    if kanidm_server_pillar.get('use_static_user', False):
      config_group = static_user_group

      server_default_config['db_path'] = f'{static_home_dir}/kanidm.db'
      server_default_config['online_backup']['path'] = f'{static_home_dir}/backups'
      server_default_config['tls_chain']= f'{static_home_dir}/chain.pem',
      server_default_config['tls_key']=   f'{static_home_dir}/key.pem',

      config["kanidmd_user_group"] = {
        "user.present": [
          {'name': config_group},
          {'system': True},
          {'usergroup': True},
          {'home': static_home_dir },
          {'shell': '/usr/sbin/nologin'},
          {'require_in': ["kanidmd_static_systemd_drop_in"]}
        ],
        "file.directory": [
          {'name': static_home_dir },
          {'user': config_group },
          {'group': config_group },
          {'mode': '0700'},
          {'require_in': ["kanidmd_static_systemd_drop_in"]}
        ]
      }

      config["kanidmd_cache_dir"] = {
        "file.directory": [
          {'name': static_cache_dir },
          {'user': config_group },
          {'group': config_group },
          {'mode': '0750'},
          {'require_in': ["kanidmd_static_systemd_drop_in"]}
        ]
      }

      config["kanidmd_static_systemd_drop_in_dir"] = {
        'file.directory': [
          {'name': static_drop_in_dir},
          {'user': 'root'},
          {'group': 'root'},
          {'mode': '0755'},
          {'require_in': ["kanidmd_static_systemd_drop_in"]},
        ]
      }

      drop_in_content = f"""# salt-managed woof meow
[Service]
DynamicUser=no
User={config_group}
"""

      config["kanidmd_static_systemd_drop_in"] = {
        'file.managed': [
          {'name': static_drop_in_file},
          {'user': 'root'},
          {'group': 'root'},
          {'mode': '0644'},
          {'contents': drop_in_content},
          {'require_in': ["kanidm_server_config"]},
          {'onchanges_in': ["kanidm_server_service"]},
        ],
        'cmd.run': [
          {'name': 'systemctl daemon-reload'},
          {'onchanges': [static_drop_in_file]},
          {'require_in': ["kanidm_server_service"]},
          {'watch_in':   ["kanidm_server_service"]}
        ]
      }

    config_content = server_default_config | kanidm_server_pillar.get('config', {})

    config["kanidm_server_config"] = {
      "file.managed": [
        {'name':    '/etc/kanidm/server.toml'},
        {'user':    'root'},
        {'group':   config_group},
        {'mode':    '0640'},
        {'require': ["kanidm_server_packages"]},
        {'contents': "# salt managed\n" + tomlmod.serialize(config_content)},
      ]
    }


    config["kanidm_server_service"] = {
      "service.running": [
        {'name': 'kanidmd.service'},
        {'enable': True},
        {'require': ["kanidm_server_config"]},
        {'watch':   ["kanidm_server_config"]},
        {'onchanges': ["kanidm_server_config"]}
      ]
    }
  else:

    config["kanidm_server_service"] = {
      'service.dead': [
        {'name': 'kanidmd.service'},
        {'enable': False},
        {'require_in': ["kanidm_server_config"]},
      ]
    }

    config["kanidmd_static_systemd_drop_in_dir"] = {
      'file.absent': [
        {'name': static_drop_in_dir},
        {'require_in': ["kanidm_server_packages"]}
      ]
    }

    config["kanidm_server_config"] = {
      "file.absent": [
        {'name':       '/etc/kanidm/server.toml'},
        {'require_in': ["kanidm_server_packages"]},
      ]
    }
    config["kanidm_server_packages"] = {
      "pkg.purged": [
        {'pkgs': kanidm_server_packages },
      ]
    }

  if kanidm_client_pillar.get('enabled', True):
    config["kanidm_client_packages"] = {
      "pkg.installed": [
        {'pkgs': kanidm_client_packages },
      ]
    }
  else:
    config["kanidm_client_packages"] = {
      "pkg.purged": [
        {'pkgs': kanidm_client_packages },
      ]
    }

  return config