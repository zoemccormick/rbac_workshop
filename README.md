# RBAC Workshop

## Setup

This workshop will go through how to configure basic RBAC rules.  The setup of the mesh, the greymatter cli, and deployment of the fibonacci service are scripted here for you, but see [Greymatter Workshops](https://github.com/deciphernow/workshops) for the full step by step setup.  The RBAC portion of this workshop also largely follows that in the [RBAC Configuration](https://github.com/DecipherNow/workshops/blob/master/training/4.%20Grey%20Matter%20Configuration/Grey%20Matter%20Configuration%20Training.md#securing-the-mesh-with-role-based-access-control-rbac) portion of the greymatter workshops.

Prereq: You will need to have the decipher quickstart certs loaded into your browser to access, [downloadable from here](https://drive.google.com/file/d/1YEyw5vEHrXhDpGuDk9RHQcQk5kFk38uz/view).

See the spreadsheet for your ec2 instance ip, and ssh into it using the posted `rbac_workshop.pem` file.

```bash
ssh -i rbac_workshop.pem ubuntu@{your-ip}
```

### Grey Matter Setup

In your ec2, you should see a directory `greymatter_setup`.  We will start Grey Matter, set up the greymatter cli, and deploy an instance of the fibonacci service.

Run the following commands to start minikube and set up Grey Matter in your ec2 instance.

```bash
cd /greymatter_setup
./setup.sh
```

You will be prompted for your docker credentials - these are the ones used for Nexus docker.production.deciphernow.com.
This will start minikube and run Grey Matter.  When you see the following pod list with everything ready, navigate to <https://{your-ec2-ip}:30000>, in a browser, and the dashboard should come up.

```bash
NAME                                     READY     STATUS    RESTARTS   AGE
catalog-5c7f658c4-dgbqb                  2/2       Running   2          3m
control-98c46795d-8ttv9                  1/1       Running   0          3m
dashboard-d7f68f588-479wg                2/2       Running   0          3m
data-0                                   2/2       Running   0          3m
data-internal-0                          2/2       Running   0          3m
data-mongo-0                             1/1       Running   0          3m
edge-b77c4dc85-xqfr5                     1/1       Running   0          3m
gm-control-api-0                         2/2       Running   0          3m
internal-data-mongo-0                    1/1       Running   0          3m
internal-jwt-security-5fd547fb54-fmnnf   2/2       Running   1          3m
internal-redis-564b47c857-r5dr4          1/1       Running   0          3m
jwt-security-6d74c8866-jlgk8             2/2       Running   1          3m
postgres-slo-0                           1/1       Running   0          3m
redis-57f7659bc7-kn9ll                   1/1       Running   0          3m
slo-684fd6b64f-l9z8l                     2/2       Running   0          3m
voyager-edge-785c4785c6-bsrz2            1/1       Running   0          3m
```

Next, setup the greymatter cli by running:

```bash
./cli.sh
source ./gmenv.sh
greymatter
```

If you see

```bash
    Options currently configured from the Environment:

        GREYMATTER_API_HOST={your-ec2-ip}:30001
        GREYMATTER_API_INSECURE=true
        GREYMATTER_API_PREFIX=/services/gm-control-api/latest
        GREYMATTER_API_SSL=true
        GREYMATTER_API_SSLCERT=/etc/ssl/quickstart/certs/quickstart.crt
        GREYMATTER_API_SSLKEY=/etc/ssl/quickstart/certs/quickstart.key
        GREYMATTER_CONSOLE_LEVEL=debug

```

the cli should be set up.

Lastly, deploy the fibonacci service by running the following commands.

```bash
./fib.sh
```

In your browser, you should now see the fibonacci service among the core services.  When this is the case, your setup is complete!

## Basic RBAC

We will start by configuring a basic RBAC policy on your fibonacci service. Using your editor of choice, `export EDITOR=vi`.  Then take a look at `greymatter get proxy fibonacci-proxy`.  You should see the following:

```bash
{
  "proxy_key": "fibonacci-proxy",
  "zone_key": "zone-default-zone",
  "name": "fibonacci",
  "domain_keys": [
    "fibonacci"
  ],
  "listener_keys": [
    "fibonacci-listener"
  ],
  "listeners": null,
  "upgrades": "",
  "active_proxy_filters": [
    "gm.metrics",
    "gm.observables"
  ],
  "proxy_filters": {
    "gm_impersonation": {},
    "gm_observables": {
      "topic": "fibonacci",
      "eventTopic": "observables",
      "kafkaServerConnection": "kafka-default.fabric.svc:9092"
    },
    "gm_oauth": {},
    "gm_inheaders": {},
    "gm_listauth": {},
    "gm_metrics": {
      "metrics_port": 8081,
      "metrics_host": "0.0.0.0",
      "metrics_dashboard_uri_path": "/metrics",
      "metrics_prometheus_uri_path": "/prometheus",
      "prometheus_system_metrics_interval_seconds": 15,
      "metrics_ring_buffer_size": 4096,
      "metrics_key_function": "depth"
    },
    "envoy_rbac": null
  },
  "checksum": "f4ca60505f600cae753ad2350ed853e3f1698c20b4942bc81f2c5aef29027c64"
}
```

As you can see, there is an `envoy_rbac` field set to null within the `proxy_filters`.  The RBAC filter is enabled the same way that the other gm proxy filters are.

Now, run `greymatter edit proxy fibonacci-proxy` and make the following changes:

1. In the `active_proxy_filters` field, add `"envoy.rbac"`. The resulting field should then look like:

    ```diff
    "active_proxy_filters": [
        "gm.metrics",
        "gm.observables",
        "envoy.rbac"
    ]
    ```

2. In the `proxy_filters` object, we will configure the filter. This will specify the rules to allow access to the Fibonacci service. Complex configurations can be tricky, but we will start with a simple config that should deny us from having access to the service. Replace `""envoy_rbac": null` with the following:

    ```diff
    "envoy_rbac": {
        "rules": {
            "action": 0,
            "policies": {
                "001": {
                    "permissions": 
                    [
                        {"any": true}
                    ],
                    "principals": [
                                    {"header": {"name": "user_dn","exact_match": "cn=not.you"}}
                    ]
                }
            }
        }
    }
    ```

The configuration above is telling the fibonacci service to give full service access (listed in the permissions) to the principals with header `user_dn` equal to `"cn=not.you"`.  Thus, any request to the fibonacci service that doesn't contain this header will be rejected. This should lock out our user (`quickstart`).

To make sure the configuration made it through without error, `greymatter get proxy fibonacci-proxy`, and you should see both of the above changes in the new object.

Once configured, it can take several minutes for the RBAC rule to take affect. If you're following the Fibonacci service sidecar logs with `sudo kubectl logs deployment/fibonacci -c sidecar -f`, you can see the point at which it starts reloading the filters. Up to a minute after this happens, the configuration will take effect.

To test that the RBAC filter has been enabled, hit  `https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/`. When the response is `RBAC: access denied`, the filter has taken affect and you are locked out of your service! You should see the same response on any endpoint of the fibonacci service, try `https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/fibonnacci/37`.

To make sure that users with `user_dn: cn=not.you` in fact _do_ have access to the service, we will take advantage of the current setup with unrestricted impersonation to run the following.

```bash
curl -k --header "user_dn: cn=not.you" --cert ./certs/quickstart.crt --key ./certs/quickstart.key https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/
```

The response should be `Alive`. So if we impersonate the "not you" user, we are allowed access.

Now, as a second example, we will allow the quickstart certificate dn full access (`PUT`, `POST`, `DELETE`, etc.) to the service.  We will also allow anyone to `GET` request the service, regardless of identity. 

To do this, we will change the `user_dn` in the RBAC policy to `CN=quickstart,OU=Engineering,O=Decipher Technology Studios,L=Alexandria,ST=Virginia,C=US`, the one from the quickstart certificate.  Then when we pass the header in the request, we should have full access to the service.  We will also add a second policy to allow _all_ users `GET` access.

> Note:  when using an RBAC configuration with multiple policies, the **policies are sorted lexicographically and enforced in this order**. In this example, the two policies are named "001" and "002", and will apply in that order because "002" sorts lexicographically _after_ "001".

`greymatter edit proxy fibonacci-proxy` again, and change the `"envoy_rbac"` policy to:

```diff
"envoy_rbac": {
    "rules": {
        "action": 0,
        "policies": {
            "001": {
                "permissions": 
                [
                    {"any": true}
                ],
                "principals": [
                                {"header": {"name": "user_dn","exact_match": "CN=quickstart,OU=Engineering,O=Decipher Technology Studios,L=Alexandria,ST=Virginia,C=US"}}
                ]
            },
            "002": {
                "permissions": [
                                {"header": {"name": ":method","exact_match": "GET"}}
                ],
                "principals": [
                    {"any": true}
                ]
            }
        }
    }
}
```

To test the new policies, we can hit `https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/` in the browser and we should see `Alive` once the RBAC filter has taken affect. This is because we are making a `GET` request to the service. Now, try the following:

```diff
# 1)
curl -k --cert ./certs/quickstart.crt --key ./certs/quickstart.key https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/

# 2)
curl -k -X PUT  --cert ./certs/quickstart.crt --key ./certs/quickstart.key https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/

# 3)
curl -k -X PUT  --header "user_dn: CN=quickstart,OU=Engineering,O=Decipher Technology Studios,L=Alexandria,ST=Virginia,C=US" --cert ./certs/quickstart.crt --key ./certs/quickstart.key https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/
```

1. The first request should have responded with `Alive`, as this is a `GET` request to the service.
2. The second request should have given `RBAC: access denied` as this was a `PUT` request without the header allowed in the policy. 
3. The third request should have also succeeded with response `Alive`, because it was a `PUT` request with the header `user_dn: CN=quickstart,OU=Engineering,O=Decipher Technology Studios,L=Alexandria,ST=Virginia,C=US` .

There are many more complex ways to configure the RBAC filter for different policies, permissions, and IDs.  Information on configuring these can be found in the Envoy documentation [here](https://www.envoyproxy.io/docs/envoy/v1.7.0/api-v2/config/rbac/v2alpha/rbac.proto).

To disable the RBAC filter, simply `greymatter edit proxy fibonacci-proxy` and delete `"envoy.rbac"` from the `"active_proxy_filters"`.


### Complex Configurations

The RBAC filter mirrors Envoy's configuration options, and thus the full set of configuration options