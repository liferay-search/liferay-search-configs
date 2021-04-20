Generate example cert files based on our docs: https://learn.liferay.com/dxp/latest/en/using-search/installing-and-upgrading-a-search-engine/elasticsearch/securing-elasticsearch.html.

1. Generate CA: `./bin/elasticsearch-certutil ca --ca-dn CN=elastic-ca`
  
    This generates a file called **`elastic-stack-ca.p12`**.
  
1. Extract the CA's certificate (public key) from the generated file: `openssl pkcs12 -in elastic-stack-ca.p12 -out elastic-stack-ca.crt -nokeys` 

    This generates a file called **`elastic-stack-ca.crt`**. You will use this to configure the trustStore/certificateAuthorities in Kibana 6.x where PKCS#12 format is not supported.
    
1. Generate self-signed node certificate in PKCS#12 format: `./bin/elasticsearch-certutil cert --ca config/certs/elastic-stack-ca.p12 --ca-pass liferay --dns localhost,example.com,es-node1,es-node2,es-node3,dxp.example.com,kibana.example.com`

    This generates a file called **`elastic-nodes.p12`.**
    
1. Generate self-signed node certificate in PEM foramt (for Kibana 6.x) using the same CA: `./bin/elasticsearch-certutil cert --pem --ca config/certs/elastic-stack-ca.p12 --ca-pass liferay --dns localhost,example.com,es-node1,es-node2,es-node3,dxp.example.com,kibana.example.com`

    This generates an archive containing two files: **`elastic-nodes.crt`** and **`elastic-nodes.key`**.
