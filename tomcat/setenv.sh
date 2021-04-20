# Path to trustStore for ES 7.x X-Pack
# (You can also use the node certificate (e.g: elastic-nodes.p12 as long as it also contains the cert of the CA.)
CATALINA_OPTS="${CATALINA_OPTS} -Djavax.net.ssl.trustStore=/PATH/TO/config/certs/elastic-stack-ca.p12 -Djavax.net.ssl.trustStorePassword=liferay -Djavax.net.ssl.trustStoreType=pkcs12"