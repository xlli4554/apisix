#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();
no_shuffle();
log_level("info");

add_block_preprocessor(sub {
    my ($block) = @_;

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }

    if (!$block->no_error_log) {
        $block->set_value("no_error_log", "[error]\n[alert]");
    }
});

run_tests;

__DATA__

=== TEST 1: sanity
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin")

            local code, body, res = t.test('/v1/schema',
                ngx.HTTP_GET,
                nil,
                [[{
                    "main": {
                        "consumer": {"type":"object"},
                        "global_rule": {"type":"object"},
                        "plugin_config": {"type":"object"},
                        "plugins": {"type":"array"},
                        "proto": {"type":"object"},
                        "route": {"type":"object"},
                        "service": {"type":"object"},
                        "ssl": {"type":"object"},
                        "stream_route": {"type":"object"},
                        "upstream": {"type":"object"},
                        "upstream_hash_header_schema": {"type":"string"},
                        "upstream_hash_vars_schema": {"type":"string"},
                    },]] .. [[
                    "plugins": {
                        "example-plugin": {
                            "version": 0.1,
                            "priority": 0,
                            "schema": {
                                "type":"object",
                                "properties": {
                                    "_meta": {
                                         "properties": {
                                             "disable": {"type": "boolean"}
                                         }
                                    }
                                }
                            },
                            "metadata_schema": {"type":"object"}
                        },
                        "basic-auth": {
                            "type": "auth",
                            "consumer_schema": {"type":"object"}
                        }
                    },
                    "stream_plugins": {
                        "mqtt-proxy": {
                            "schema": {
                                "type":"object",
                                "properties": {
                                    "_meta": {
                                         "properties": {
                                             "disable": {"type": "boolean"}
                                         }
                                    }
                                }
                            },
                            "priority": 1000
                        }
                    }
                }]]
                )
            ngx.status = code
            ngx.say(body)
        }
    }
--- response_body
passed



=== TEST 2: confirm the scope of plugin
--- yaml_config
apisix:
  node_listen: 1984
  admin_key: null
plugins:
  - batch-requests
  - error-log-logger
  - server-info
  - example-plugin
  - node-status
--- config
    location /t {
        content_by_lua_block {
            local json = require("toolkit.json")
            local t = require("lib.test_admin").test

            local code, message, res = t('/v1/schema',
                ngx.HTTP_GET
            )

            if code >= 300 then
                ngx.status = code
                ngx.say(message)
                return
            end

            res = json.decode(res)
            local global_plugins = {}
            local plugins = res["plugins"]
            for k, v in pairs(plugins) do
                if v.scope == "global" then
                    global_plugins[k] = v.scope
                end
            end
            ngx.say(json.encode(global_plugins))
        }
    }
--- response_body
{"batch-requests":"global","error-log-logger":"global","node-status":"global","server-info":"global"}
