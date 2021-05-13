For `Elasticsearch 6.x, 7.x`.

Generate example cert files based on our docs: https://learn.liferay.com/dxp/latest/en/using-search/installing-and-upgrading-a-search-engine/elasticsearch/securing-elasticsearch.html.

## General commands

1. Generate CA: `./bin/elasticsearch-certutil ca --ca-dn CN=elastic-ca`
  
This generates a file called **`elastic-stack-ca.p12`**.
  
1. Extract the CA's certificate (public key) from the generated file: `openssl pkcs12 -in elastic-stack-ca.p12 -out elastic-stack-ca.crt -nokeys` 

This generates a file called **`elastic-stack-ca.crt`**. You will use this to configure the trustStore/certificateAuthorities in Kibana 6.x where PKCS#12 format is not supported.
    
1. Generate self-signed node certificate in PKCS#12 format: `./bin/elasticsearch-certutil cert --ca config/certs/elastic-stack-ca.p12 --ca-pass liferay --dns localhost,example.com,es-node1,es-node2,es-node3,dxp.example.com,kibana.example.com`

This generates a file called **`elastic-nodes.p12`**.
    
1. Generate self-signed node certificate in PEM foramt (for Kibana 6.x) using the same CA: `./bin/elasticsearch-certutil cert --pem --ca config/certs/elastic-stack-ca.p12 --ca-pass liferay --dns localhost,example.com,es-node1,es-node2,es-node3,dxp.example.com,kibana.example.com`

This generates an archive containing two files: **`elastic-nodes.crt`** and **`elastic-nodes.key`**.

**Note**: Across the elastic stack where you need configure "trust stores", you most probably will want/need to use certificate files without a private key (`elastic-stack-ca.crt`) in a real scenario. It is just in this super-simplified setup where we can operate with the `elastic-stack-ca.p12` file which also includes the CA's private key.

## PKI

To use [PKI user authentication](https://www.elastic.co/guide/en/elasticsearch/reference/current/pki-realm.html) in Elasticsearch, you should generate a certificate for each client node in your stack with specific details in order to map a given certificate ("Subject Name") to an Elasticsearch role.

Let's say, we want to setup the following associations:
* Liferay DXP's host: `dxp.example.com` ==> Subject Name: `CN=dxp.example.com,OU=Search,DC=dxp,DC=example,DC=com` ==> Elasticsearch role: `superuser`
* Kibana's host: `kibana.example.com` ==> Subject Name: `CN=kibana.example.com,OU=Search,DC=kibana,DC=example,DC=com` ==> Elasticsearch role: `kibana_system`

Assuming that you already have **`elastic-stack-ca.p12`** generated, run these commands below from your `ES_HOME` folder to generate the necessary certificates:

**PKCS#12**:

	./bin/elasticsearch-certutil cert --ca config/certs/elastic-stack-ca.p12 --ca-pass liferay --dns localhost,dxp.example.com --name "CN=dxp.example.com,OU=Search,DC=dxp,DC=example,DC=com" --out dxp.example.com.p12

	./bin/elasticsearch-certutil cert --ca config/certs/elastic-stack-ca.p12 --ca-pass liferay --dns localhost,kibana.example.com --name "CN=kibana.example.com,OU=Search,DC=kibana,DC=example,DC=com" --out kibana.example.com.p12

**PEM**:

	./bin/elasticsearch-certutil cert --pem --ca config/certs/elastic-stack-ca.p12 --ca-pass liferay --dns localhost,dxp.example.com --name "CN=dxp.example.com,OU=Search,DC=dxp,DC=example,DC=com"

	./bin/elasticsearch-certutil cert --pem --ca config/certs/elastic-stack-ca.p12 --ca-pass liferay --dns localhost,kibana.example.com --name "CN=kibana.example.com,OU=Search,DC=kibana,DC=example,DC=com"

(Note: extract the files from the generated archive and rename them to `*.key` and `*.crt`.)

### Test PKI Authentication

You can run this `curl` command below to test the authentication using the certificates when Elasticsearch is already configured to use PKI and require clients to authenticate on the `HTTP` layer:

	curl https://localhost:9200/_xpack/security/_authenticate?pretty --cert dxp.example.com.crt --key dxp.example.com.key --cacert elastic-stack-ca.crt -k -v

The response should look something like this:

```json
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Connected to localhost (127.0.0.1) port 9200 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: elastic-stack-ca.crt
  CApath: /etc/ssl/certs
...
{
  "username" : "dxp.example.com",
  "roles" : [
    "superuser"
  ],
  "full_name" : null,
  "email" : null,
  "metadata" : {
    "pki_dn" : "CN=dxp.example.com, OU=Search, DC=dxp, DC=example, DC=com"
  },
  "enabled" : true,
  "authentication_realm" : {
    "name" : "pki1",
    "type" : "pki"
  },
  "lookup_realm" : {
    "name" : "pki1",
    "type" : "pki"
  }
}
* Connection #0 to host localhost left intact
```

The `roles` list should include the role you mapped the "Subject Name" to in your `ES_HOME/config/role_mapping.yml`.