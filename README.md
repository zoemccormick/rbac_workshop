# RBAC Workshop

This workshop will go through how to restrict service access via the Grey Matter RBAC filter.  

The setup of the mesh, the greymatter cli, and deployment of the fibonacci service are scripted here for you, but see [Greymatter Workshops](https://github.com/deciphernow/workshops) for the full step by step setup.  The RBAC portion of this workshop also aligns with the [RBAC Configuration](https://github.com/DecipherNow/workshops/blob/master/training/4.%20Grey%20Matter%20Configuration/Grey%20Matter%20Configuration%20Training.md#securing-the-mesh-with-role-based-access-control-rbac) portion of the greymatter workshops.

Prereq: You will need to have the decipher quickstart certs loaded into your browser to access, [downloadable from here](https://drive.google.com/file/d/1YEyw5vEHrXhDpGuDk9RHQcQk5kFk38uz/view).

See the spreadsheet for your ec2 instance ip, and ssh into it using the posted `rbac_workshop.pem` file.

```bash
ssh -i rbac_workshop.pem ubuntu@{your-ip}
```

## Grey Matter Setup

In your ec2, you should see a directory `greymatter_setup`.  We will start Grey Matter, set up the greymatter cli, and deploy an instance of the fibonacci service.

Run the following commands to start minikube and set up Grey Matter in your ec2 instance.

```bash
cd greymatter_setup/
./setup.sh
```

You will be prompted for your docker credentials - these are the ones used for Nexus docker.production.deciphernow.com.
This will start minikube and run Grey Matter.  When you see the following pod list with everything ready (this will take about ~5 minutes), navigate to `https://{your-ec2-ip}:30000`, in a browser, and the dashboard should come up.

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

Lastly, deploy the fibonacci service by running

```bash
./fib.sh
```

In your browser, you should now see the fibonacci service among the core services.  Navigate to `https://{your-ec2-ip}:30000/services/fibonacci/1.0/>` if you see `Alive`, the fibonacci service is running.  When this is the case, your setup is complete!

## Basic RBAC

It should be noted that for testing purposes we will simply set a `user_dn` header on curl requests - this will not be possible with the impersonation filter properly configured.

We will start by configuring a basic RBAC policy on your fibonacci service. Using your editor of choice, `export EDITOR=vi # or whatever`.  Then take a look at `greymatter get proxy fibonacci-proxy`.  You should see the following:

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
curl -k --header "user_dn: cn=not.you" --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/
```

The response should be `Alive`. So if we impersonate the "not you" user, we are allowed access.

## A more useful example

Now, as a second example, we will allow the quickstart certificate access to `GET` request the service.  The user `cn=not.you` will still have full access to the service.

To do this, we will add a policy that allows the user `CN=quickstart,OU=Engineering,O=Decipher Technology Studios,=Alexandria,=Virginia,C=US` `GET` permissions to the fibonacci service. Check out the following configuration.  When a request comes in, it will be matched based on policy in lexicographical order, so below if the user_dn is `cn=not.you`, the RBAC filter will allow full access, if it is not, it will check the next policy for a matching action and id.

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
                                    {"header": {"name": "user_dn","exact_match": "cn=not.you"}}
                ]
                },
            "002": {
                "permissions":
                [
                    {"header": {"name": ":method","exact_match": "GET"}}
                ],
                "principals": [
                                {"header": {"name": "user_dn","exact_match": "CN=quickstart,OU=Engineering,O=Decipher Technology Studios,=Alexandria,=Virginia,C=US"}}
                ]
            }
        }
    }
}
```

Again, give the filter several minutes to take effect. To test the new policies, hit `https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/` in the browser and we should see `Alive` once the RBAC filter has been configured. This is because we are making a `GET` request to the service. Now, try the following `PUT` requests to make sure only the correct user (`cn=not.you`) has `PUT` access:

1. This request should respond with `RBAC: access denied`, as it is a `PUT` request to the service, and we do not have the user dn `cn=not.you`.

    ```diff
    curl -k -X PUT  --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/
    ```

2. This should succeed with response `Alive`, because it was a `PUT` request with the header `user_dn: cn=not.you`.

    ```diff
    curl -k -X PUT  --header "user_dn: cn=not.you" --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/
    ```

## A more complex configuration

There are many more complex ways to configure the RBAC filter for different policies, permissions, and IDs.  Information on configuring these can be found in the Envoy documentation [here](https://www.envoyproxy.io/docs/envoy/v1.7.0/api-v2/config/rbac/v2alpha/rbac.proto).

If we have time in the workshop, lets try a more complex configuration.

Try `greymatter edit proxy fibonacci-proxy` and change the rbac configuration to the following:

```diff
"envoy_rbac": {
        "rules": {
            "action": 0,
            "policies": {
                "001": {
                    "permissions": [
                            {
                                "or_rules": {
                                    "rules": [
                                        {
                                            "header": {
                                                "name": ":method",
                                                "exact_match": "PUT"
                                            }
                                        },
                                        {
                                            "header": {
                                                "name": ":method",
                                                "exact_match": "DELETE"
                                            }
                                        },
                                        {
                                            "header": {
                                                "name": ":method",
                                                "exact_match": "POST"
                                            }
                                        }
                                    ]
                                }
                            }
                        ],
                    "principals": [
                            {
                                "or_ids": {
                                    "ids": [
                                        {
                                        "header": {
                                            "name": "user_dn",
                                            "exact_match": "CN=first1.last1"
                                        }
                                    },
                                    {
                                        "header": {
                                            "name": "user_dn",
                                            "exact_match": "CN=first2.last2"
                                        }
                                    }
                                    ]
                                }
                            }
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

This policy is allowing ids with user_dn equal to `CN=first1.last1` **or** `CN=first2.last2` permission to `PUT` or `DELETE` or `POST` request the service. It is also allowing anyone to get request the service.

To test this policy, navigate to the the same url `https://{your-ec2-public-ip}:{port}/services/fibonacci/1.0/` in the browser. You should have access to the service here because this is a `GET` request.

Now, try the following:

1. This is a PUT request, a DELETE request, a POST request, and a GET request to the service. The response should be `RBAC: access denied` for the first three requests because the user_dn is coming from our cert and will not match `CN=first1.last1` or `CN=first2.last2`.  The last request should succeed with response `Alive` because anyone is allowed to `GET` request the service.

    ```bash
    #1
    curl -k -X PUT  --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/
    #2
    curl -k -X POST  --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/
    #3
    curl -k -X DELETE  --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/
    #4
    curl -k --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/

    ```

2. This is a PUT request, a DELETE request, and a POST request to the service with the user_dn set to `CN=first1.last1`, and then the same three requests with user_dn set to `CN=first2.last2`.  All six of the responses to these requests should be 'Alive'.

    ```bash
    #1
    curl -k -X PUT  --header "user_dn: CN=first1.last1" --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/

    #2
    curl -k -X POST  --header "user_dn: CN=first1.last1" --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/

    #3
    curl -k -X DELETE  --header "user_dn: CN=first1.last1" --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/

    #4
    curl -k -X PUT  --header "user_dn: CN=first2.last2" --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/

    #5
    curl -k -X POST  --header "user_dn: CN=first2.last2" --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/

    #6
    curl -k -X DELETE  --header "user_dn: CN=first2.last2" --cert /etc/ssl/quickstart/certs/quickstart.crt --key /etc/ssl/quickstart/certs/quickstart.key https://$GREYMATTER_API_HOST/services/fibonacci/1.0/

    ```

Yay! You have now completed three configurations of the RBAC filter!
As you can see, large configurations can quickly become tricky.  It is important to remember ordering, and to keep in mind that when the actions are assessed, the policies are traversed in order until a match is found.

To disable the RBAC filter, simply `greymatter edit proxy fibonacci-proxy` and delete `"envoy.rbac"` from the `"active_proxy_filters"`.