# Troubleshooting Liferay DXP and Elasticsearch Integration

This article is a repository of solutions and workarounds based on past cases. In the interest of providing helpful knowledge immediately, this may be presented in an unedited form. Users are responsible for verifying how well the information fits with their particular situation and project requirements. 

## Troubleshooting Resources at learn.liferay.com

https://learn.liferay.com/dxp/latest/en/using-search/installing-and-upgrading-a-search-engine/elasticsearch/troubleshooting-elasticsearch-installation.html

## Troubleshooting Resources by Elastic

* https://www.elastic.co/elasticon/archive/2021/global/troubleshooting-your-elasticsearch-cluster-like-an-elastic-support-engineer
* https://github.com/elastic/support-diagnostics

## Information to Gather to help Diagnosing

**Basic Information**
* Elasticsearch exact version and number of nodes
* Kibana exact version (if applicable)
* Liferay DXP patch level
* Liferay Elasticsearch connector version (if installed from Marketplace)
* Version of the LES applications like LTR, CCR, Monitoring (if applicable)  

**Standard Config files**
You can find the most common config files for DXP, Elasticsearch and Kibana that you should obtain from the customer (if applicable) in https://github.com/liferay-search/liferay-search-configs. When the customer has a multi-node ES cluster, it's better to collect the config files from each ES node. (Same applies if they are clustering DXP.)

**Additional config files & environment information**:
Besides those files, you may also need to provide:
* JDK version (especially in case of DXP 7.0-7.2 where DXP and ES must be using the same JDK version)
* ES stack deployment type: on-prem (local) / Elastic Cloud / self-managed in cloud deployed on AWS/Azure/GCP, dockerized - non-dockerized
* DXP-ES architecture: proxy?, load balancer?
* public certificates of the nodes and the CA
* `ES_HOME/jvm.options` file(s) 

**Log files**
* `ES_HOME/logs` from the nodes
* Kibana console log (if applicable)
* DXP logs
* Tomcat's setenv.sh/bat or the full list of JVM arguments of their application server (if applicable)

**Elasticsearch Support Diagnostics Tool Output**

When it comes to issues with sharding/indexes allocation, routing, index size etc. it can be useful to run the Elasticsearch Support Diagnostics Tool and examine/provide the output. See https://help.liferay.com/hc/en-us/articles/360034567992--LES-How-to-install-and-run-the-Elastic-Support-Diagnostics-Troubleshooting-Utility.

Once you have the output, look at the "cat" folder inside the archive: "cat_allocation.json", "cat_indices.json" and "cat_shards.json" are our primary interest to get an information, but the other files can also contain useful information depending on the nature of the issue.

## Example Configs

Here you can find example config files based on our docs https://github.com/liferay-search/liferay-search-configs. You can compare the files shared by the customer with these to identify differences, missing/invalid settings.


## Troubleshooting Connection Issues


### Issue 1: networkHostAddresses / transportAddresses in connector config do not match the actual host/address of the Elasticsearch nodes

**Issue 1 - DXP 7.3+: java.net.ConnectException: Timeout connecting to**

```
Caused by: java.net.ConnectException: Timeout connecting to
	at org.elasticsearch.client.RestClient.extractAndWrapCause(RestClient.java:849) ~[?:?]
	at org.elasticsearch.client.RestClient.performRequest(RestClient.java:259) ~[?:?]
	at org.elasticsearch.client.RestClient.performRequest(RestClient.java:246) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.internalPerformRequest(RestHighLevelClient.java:1613) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.performRequest(RestHighLevelClient.java:1583) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.performRequestAndParseEntity(RestHighLevelClient.java:1553) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.bulk(RestHighLevelClient.java:533) ~[?:?]
	at com.liferay.portal.search.elasticsearch7.internal.search.engine.adapter.document.BulkDocumentRequestExecutorImpl.getBulkResponse(BulkDocumentRequestExecutorImpl.java:158) ~[?:?]
	... 55 more
```

**Error 1 - DXP  7.0-7.2: org.elasticsearch.client.transport.NoNodeAvailableException**

```
2021-06-04 17:53:06.654 ERROR [main][ElasticsearchEngineConfigurator:93] bundle com.liferay.portal.search.elasticsearch7.impl:4.0.9 (83)[com.liferay.portal.search.elasticsearch7.internal.ElasticsearchEngineConfigurator(16)] : The activate method has thrown an exception 
java.lang.RuntimeException: org.elasticsearch.client.transport.NoNodeAvailableException: NoNodeAvailableException[None of the configured nodes are available: [{#transport#-1}{xDAEykAeQ-SgT_hYW2a2uw}{es-node1-prod}{192.168.23.95:9300}]]
	at org.elasticsearch.client.transport.TransportClientNodesService.ensureNodesAreAvailable(TransportClientNodesService.java:352)
	at org.elasticsearch.client.transport.TransportClientNodesService.execute(TransportClientNodesService.java:248)
	at org.elasticsearch.client.transport.TransportProxyClient.execute(TransportProxyClient.java:57)
	at org.elasticsearch.client.transport.TransportClient.doExecute(TransportClient.java:395)
	at org.elasticsearch.client.support.AbstractClient.execute(AbstractClient.java:409)
	at org.elasticsearch.client.support.AbstractClient.execute(AbstractClient.java:398)
	at org.elasticsearch.action.ActionRequestBuilder.execute(ActionRequestBuilder.java:45)
	at org.elasticsearch.action.ActionRequestBuilder.get(ActionRequestBuilder.java:52)
	at com.liferay.portal.search.elasticsearch7.internal.search.engine.adapter.cluster.HealthClusterRequestExecutorImpl.execute(HealthClusterRequestExecutorImpl.java:46)
```

#### Issue 1: Diagnosing & Resolution

The above error indicates that ES connector in DXP is attempting to connect to Elasticsearch using host `es-node1-prod` and it can't find any available nodes. Obtain the Elasticsearch node(s) logs and look for lines like 

```
[2021-06-04T17:31:22,472][INFO ][o.e.t.TransportService   ] [es-node1] publish_address {es-node1/192.168.0.17:9300}, bound_addresses {192.168.0.17:9300}
(...)
[2021-06-04T17:31:23,080][INFO ][o.e.h.AbstractHttpServerTransport] [es-node1] publish_address {es-node1/192.168.0.17:9200}, bound_addresses {192.168.0.17:9200}
```

indicating the actual address of the given node. In this example, it is `es-node1/192.168.0.17:9300` for the Transport address and `es-node1/192.168.0.17:9200` for the HTTP address. Therefore, the connector config in DXP should use
* `networkHostAddresses=["http:es-node1:9200"]` on DXP 7.3+ (`["es-node1:9200"]` also works)
* `transportAddresses=["es-node1:9300"]` on DXP 7.0-7.2.

## Issue 2: TLS/SSL is enabled & configured in Elasticsearch, but DXP is still attempting to communicate over a unencrypted channel

**Issue 2 - DXP 7.3+: org.apache.http.ConnectionClosedException: Connection is closed**

```
Caused by: org.apache.http.ConnectionClosedException: Connection is closed
	at org.elasticsearch.client.RestClient.extractAndWrapCause(RestClient.java:839) ~[?:?]
	at org.elasticsearch.client.RestClient.performRequest(RestClient.java:259) ~[?:?]
	at org.elasticsearch.client.RestClient.performRequest(RestClient.java:246) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.internalPerformRequest(RestHighLevelClient.java:1613) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.performRequest(RestHighLevelClient.java:1583) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.performRequestAndParseEntity(RestHighLevelClient.java:1553) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.bulk(RestHighLevelClient.java:533) ~[?:?]
	at com.liferay.portal.search.elasticsearch7.internal.search.engine.adapter.document.BulkDocumentRequestExecutorImpl.getBulkResponse(BulkDocumentRequestExecutorImpl.java:158) ~[?:?]
	... 44 more
Caused by: org.apache.http.ConnectionClosedException: Connection is closed
	at org.apache.http.nio.protocol.HttpAsyncRequestExecutor.endOfInput(HttpAsyncRequestExecutor.java:356) ~[?:?]
	at org.apache.http.impl.nio.DefaultNHttpClientConnection.consumeInput(DefaultNHttpClientConnection.java:261) ~[?:?]
	at org.apache.http.impl.nio.client.InternalIODispatch.onInputReady(InternalIODispatch.java:81) ~[?:?]
	at org.apache.http.impl.nio.client.InternalIODispatch.onInputReady(InternalIODispatch.java:39) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIODispatch.inputReady(AbstractIODispatch.java:114) ~[?:?]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.readable(BaseIOReactor.java:162) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvent(AbstractIOReactor.java:337) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvents(AbstractIOReactor.java:315) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.execute(AbstractIOReactor.java:276) ~[?:?]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.execute(BaseIOReactor.java:104) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractMultiworkerIOReactor$Worker.run(AbstractMultiworkerIOReactor.java:591) ~[?:?]
	... 1 more
```

**Issue 2 - DXP 7.0-7.2: org.elasticsearch.client.transport.NoNodeAvailableException**

TBA

**Issue 2: Elasticsearch log**

```
[2021-06-04T18:09:11,925][WARN ][o.e.x.s.t.n.SecurityNetty4HttpServerTransport] [es-node1] received plaintext http traffic on an https channel, closing connection Netty4HttpChannel{localAddress=0.0.0.0/0.0.0.0:9200, remoteAddress=/192.168.0.17:41104}
```

or 

```
[2021-06-04T18:11:13,045][WARN ][o.e.x.c.s.t.n.SecurityNetty4Transport] [es-node1] received plaintext traffic on an encrypted channel, closing connection Netty4TcpChannel{localAddress=0.0.0.0/0.0.0.0:9300, remoteAddress=/192.168.0.17:34346}
```

#### Issue 2: Diagnosing & Resolution

The Elasticsearch WARNs are indicating that the server received plaintext traffic on an encrypted channel. Obtaining the `elasticsearch.yml` if it has `xpack.security.*` properties set for the transport and/or http layers (and optionally you also see `xpack.security.enabled: true`) it means Elasticsearch has X-Pack Security enabled so the connector in DXP must also be configured accordingly.

See https://learn.liferay.com/dxp/7.x/en/using-search/installing-and-upgrading-a-search-engine/elasticsearch/securing-elasticsearch.html.

## Issue 3: Elasticsearch node's host does not match the DNS names in its certificate

**Issue 3 - DXP 7.3+: javax.net.ssl.SSLPeerUnverifiedException**

```
Caused by: javax.net.ssl.SSLPeerUnverifiedException: Host name 'es-node1' does not match the certificate subject provided by the peer (CN=elastic-nodes)
	at org.apache.http.nio.conn.ssl.SSLIOSessionStrategy.verifySession(SSLIOSessionStrategy.java:209) ~[?:?]
	at org.apache.http.nio.conn.ssl.SSLIOSessionStrategy$1.verify(SSLIOSessionStrategy.java:188) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.doHandshake(SSLIOSession.java:360) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.isAppInputReady(SSLIOSession.java:523) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIODispatch.inputReady(AbstractIODispatch.java:120) ~[?:?]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.readable(BaseIOReactor.java:162) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvent(AbstractIOReactor.java:337) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvents(AbstractIOReactor.java:315) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.execute(AbstractIOReactor.java:276) ~[?:?]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.execute(BaseIOReactor.java:104) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractMultiworkerIOReactor$Worker.run(AbstractMultiworkerIOReactor.java:591) ~[?:?]
	... 1 more
```

**Issue 3 - DXP 7.0-7.2: org.elasticsearch.client.transport.NoNodeAvailableException: NoNodeAvailableException and java.security.cert.CertificateException: No subject alternative DNS name matching found.**

Thrown only when `transportSSLVerificationMode="full"` is set in `*.XPackSecurityConfiguration.config` in DXP, so the client (connector in DXP) is not only verifying that the Elasticsearch server node's certficate is signed by a trusted CA, but it's also performing host name/IP address verification.

```
[2021-06-08T17:09:24,557][WARN ][o.e.c.s.DiagnosticTrustManager] [
ode_name]failed to establish trust with server at [es-node1]; the server provided a certificate with subject name [CN=elastic-nodes] and fingerprint [065071bd5b26e83b2903b09179acf4a48851d775]; the certificate has subject alternative names [DNS:localhost,DNS:dxp.example.com,DNS:es-node-1,IP:127.0.0.1,DNS:es-node2,DNS:es-node3,DNS:kibana.example.com]; the certificate is issued by [CN=elastic-ca]; the certificate is signed by (subject [CN=elastic-ca] fingerprint [39b9312498b37827bdf8f64faef397449c0c0686] {trusted issuer}) which is self-issued; the [CN=elastic-ca] certificate is trusted in this ssl context ([xpack.security.transport.ssl])
java.security.cert.CertificateException: No subject alternative DNS name matching es-node1 found.
	at sun.security.util.HostnameChecker.matchDNS(HostnameChecker.java:212) ~[?:?]
	at sun.security.util.HostnameChecker.match(HostnameChecker.java:103) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkIdentity(X509TrustManagerImpl.java:455) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkIdentity(X509TrustManagerImpl.java:429) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkTrusted(X509TrustManagerImpl.java:283) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkServerTrusted(X509TrustManagerImpl.java:141) ~[?:?]
	at org.elasticsearch.common.ssl.DiagnosticTrustManager.checkServerTrusted(DiagnosticTrustManager.java:110) [elasticsearch-ssl-config-7.9.0.jar:7.9.0]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.checkServerCerts(CertificateMessage.java:1334) [?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.onConsumeCertificate(CertificateMessage.java:1231) [?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.consume(CertificateMessage.java:1174) [?:?]
	at sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:392) [?:?]
	at sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:444) [?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1074) [?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1061) [?:?]
	at java.security.AccessController.doPrivileged(Native Method) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask.run(SSLEngineImpl.java:1008) [?:?]
	at io.netty.handler.ssl.SslHandler.runAllDelegatedTasks(SslHandler.java:1542) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.ssl.SslHandler.runDelegatedTasks(SslHandler.java:1556) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.ssl.SslHandler.unwrap(SslHandler.java:1440) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.ssl.SslHandler.decodeJdkCompatible(SslHandler.java:1267) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.ssl.SslHandler.decode(SslHandler.java:1314) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.codec.ByteToMessageDecoder.decodeRemovalReentryProtection(ByteToMessageDecoder.java:501) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.codec.ByteToMessageDecoder.callDecode(ByteToMessageDecoder.java:440) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.codec.ByteToMessageDecoder.channelRead(ByteToMessageDecoder.java:276) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:379) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:365) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.fireChannelRead(AbstractChannelHandlerContext.java:357) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.DefaultChannelPipeline$HeadContext.channelRead(DefaultChannelPipeline.java:1410) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:379) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:365) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.DefaultChannelPipeline.fireChannelRead(DefaultChannelPipeline.java:919) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.AbstractNioByteChannel$NioByteUnsafe.read(AbstractNioByteChannel.java:163) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKey(NioEventLoop.java:714) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKeysPlain(NioEventLoop.java:615) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKeys(NioEventLoop.java:578) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.run(NioEventLoop.java:493) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.util.concurrent.SingleThreadEventExecutor$4.run(SingleThreadEventExecutor.java:989) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.util.internal.ThreadExecutorMap$2.run(ThreadExecutorMap.java:74) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at java.lang.Thread.run(Thread.java:834) [?:?]
[2021-06-08T17:09:24,559][WARN ][o.e.t.TcpTransport       ] [
ode_name]exception caught on transport layer [Netty4TcpChannel{localAddress=0.0.0.0/0.0.0.0:40688, remoteAddress=null}], closing connection
io.netty.handler.codec.DecoderException: javax.net.ssl.SSLHandshakeException: No subject alternative DNS name matching es-node1 found.
	at io.netty.handler.codec.ByteToMessageDecoder.callDecode(ByteToMessageDecoder.java:471) ~[netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.codec.ByteToMessageDecoder.channelRead(ByteToMessageDecoder.java:276) ~[netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:379) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:365) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.fireChannelRead(AbstractChannelHandlerContext.java:357) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.DefaultChannelPipeline$HeadContext.channelRead(DefaultChannelPipeline.java:1410) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:379) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:365) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.DefaultChannelPipeline.fireChannelRead(DefaultChannelPipeline.java:919) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.AbstractNioByteChannel$NioByteUnsafe.read(AbstractNioByteChannel.java:163) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKey(NioEventLoop.java:714) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKeysPlain(NioEventLoop.java:615) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKeys(NioEventLoop.java:578) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.run(NioEventLoop.java:493) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.util.concurrent.SingleThreadEventExecutor$4.run(SingleThreadEventExecutor.java:989) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.util.internal.ThreadExecutorMap$2.run(ThreadExecutorMap.java:74) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at java.lang.Thread.run(Thread.java:834) [?:?]
Caused by: javax.net.ssl.SSLHandshakeException: No subject alternative DNS name matching es-node1 found.
```

**Issue 3: Elasticsearch log**

For Transport connections:

```
[2021-06-08T17:06:03,540][WARN ][o.e.x.c.s.t.n.SecurityNetty4Transport] [es-node1] client did not trust this server's certificate, closing connection Netty4TcpChannel{localAddress=0.0.0.0/0.0.0.0:9300, remoteAddress=/192.168.0.17:40486}
```

#### Issue 3: Diagnosing & Resolution

This error indicates that the Elasticsearch server node's host is not listed in the certificate it is presenting to the client (DXP) during the SSL handshake as a Subject Alternative Name: server's host: `es-node1` in this example, while the certificate is containing `es-node-1`.

Open the server's certificate and DNS names/IP addresses under the `Subject Alternative Names` category and check if the server's host is there. If it is not, the cert should be updated.

## Issue 4: Client authentication fails due to incorrect X-Pack user credentials (username or password)

**Issue 4 - DXP 7.3+: org.elasticsearch.ElasticsearchStatusException**

If the `password` is incorrect:
```
2021-06-04 18:28:29.114 ERROR [liferay/scheduler_dispatch-6][ParallelDestination:59] Unable to process message {destinationName=liferay/scheduler_dispatch, response=null, responseDestinationName=null, responseId=null, payload=null, values={GROUP_NAME=com.liferay.portal.workflow.metrics.internal.messaging.WorkflowMetricsSLADefinitionTransformerMessageListener, companyId=20102, groupId=0, DESTINATION_NAME=liferay/scheduler_dispatch, EXCEPTIONS_MAX_SIZE=0, JOB_STATE=com.liferay.portal.kernel.scheduler.JobState@373e23f1, STORAGE_TYPE=MEMORY_CLUSTERED, JOB_NAME=com.liferay.portal.workflow.metrics.internal.messaging.WorkflowMetricsSLADefinitionTransformerMessageListener}}
com.liferay.portal.kernel.messaging.MessageListenerException: java.lang.RuntimeException: org.elasticsearch.ElasticsearchStatusException: ElasticsearchStatusException[method [HEAD], host [https://es-node-1:9200], URI [/liferay-20102-workflow-metrics-processes?ignore_throttled=false&include_type_name=true&ignore_unavailable=false&expand_wildcards=open&allow_no_indices=true], status line [HTTP/1.1 401 Unauthorized]]; nested: ResponseException[method [HEAD], host [https://es-node-1:9200], URI [/liferay-20102-workflow-metrics-processes?ignore_throttled=false&include_type_name=true&ignore_unavailable=false&expand_wildcards=open&allow_no_indices=true], status line [HTTP/1.1 401 Unauthorized]];
	at com.liferay.portal.kernel.messaging.BaseMessageListener.receive(BaseMessageListener.java:41) ~[portal-kernel.jar:?]
	at com.liferay.portal.kernel.scheduler.messaging.SchedulerEventMessageListenerWrapper._processMessage(SchedulerEventMessageListenerWrapper.java:127) ~[portal-kernel.jar:?]
	at com.liferay.portal.kernel.scheduler.messaging.SchedulerEventMessageListenerWrapper.receive(SchedulerEventMessageListenerWrapper.java:98) ~[portal-kernel.jar:?]
	at com.liferay.portal.kernel.messaging.InvokerMessageListener.receive(InvokerMessageListener.java:74) ~[portal-kernel.jar:?]
	at com.liferay.portal.messaging.internal.ParallelDestination$1.run(ParallelDestination.java:56) [bundleFile:?]
	at java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1128) [?:?]
	at java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:628) [?:?]
	at java.lang.Thread.run(Thread.java:834) [?:?]
Caused by: java.lang.RuntimeException: org.elasticsearch.ElasticsearchStatusException: ElasticsearchStatusException[method [HEAD], host [https://es-node-1:9200], URI [/liferay-20102-workflow-metrics-processes?ignore_throttled=false&include_type_name=true&ignore_unavailable=false&expand_wildcards=open&allow_no_indices=true], status line [HTTP/1.1 401 Unauthorized]]; nested: ResponseException[method [HEAD], host [https://es-node-1:9200], URI [/liferay-20102-workflow-metrics-processes?ignore_throttled=false&include_type_name=true&ignore_unavailable=false&expand_wildcards=open&allow_no_indices=true], status line [HTTP/1.1 401 Unauthorized]];
	at org.elasticsearch.client.RestHighLevelClient.parseResponseException(RestHighLevelClient.java:1866) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.internalPerformRequest(RestHighLevelClient.java:1626) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.performRequest(RestHighLevelClient.java:1583) ~[?:?]
```

If the `username` is incorrect:

```
2021-06-04 18:34:49.059 ERROR [com.liferay.data.engine.internal.petra.executor.DataEngineNativeObjectPortalExecutor-2][DataEngineNativeObjectPortalExecutor:163] java.lang.RuntimeException: org.elasticsearch.ElasticsearchStatusException: ElasticsearchStatusException[Elasticsearch exception [type=security_exception, reason=unable to authenticate user [elasticc] for REST request [/_bulk?refresh=true&timeout=1m]]]
java.lang.RuntimeException: org.elasticsearch.ElasticsearchStatusException: ElasticsearchStatusException[Elasticsearch exception [type=security_exception, reason=unable to authenticate user [elasticc] for REST request [/_bulk?refresh=true&timeout=1m]]]
	at org.elasticsearch.rest.BytesRestResponse.errorFromXContent(BytesRestResponse.java:187) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.parseEntity(RestHighLevelClient.java:1892) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.parseResponseException(RestHighLevelClient.java:1869) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.internalPerformRequest(RestHighLevelClient.java:1626) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.performRequest(RestHighLevelClient.java:1583) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.performRequestAndParseEntity(RestHighLevelClient.java:1553) ~[?:?]
	at org.elasticsearch.client.RestHighLevelClient.bulk(RestHighLevelClient.java:533) ~[?:?]
```

**Issue 4 - DXP 7.0-.7.2: org.elasticsearch.client.transport.NoNodeAvailableException**

```
2021-06-07 17:41:57.715 ERROR [main][SLATaskResultWorkflowMetricsIndexer:93] bundle com.liferay.portal.workflow.metrics.service:1.0.37 (196)[com.liferay.portal.workflow.metrics.internal.search.index.SLATaskResultWorkflowMetricsIndexer(663)] : The activate method has thrown an exception 
com.liferay.portal.kernel.exception.SystemException: java.lang.RuntimeException: org.elasticsearch.client.transport.NoNodeAvailableException: NoNodeAvailableException[None of the configured nodes are available: [{#transport#-1}{6t3ij6XkTECyV6HEejCe_Q}{es-node1}{192.168.0.17:9300}]]
```

**Issue 4 - Elasticsearch log**

```
[2021-06-04T18:30:29,114][INFO ][o.e.x.s.a.AuthenticationService] [es-node1] Authentication of [elastic] was terminated by realm [reserved] - failed to authenticate user [elastic]
```

#### Issue 4: Diagnosing & Resolution

The password configured at the client (DXP) side is incorrect and the server fails to authenticat the user `elastic`. Obtain the related connector config file and check with the customer the username/password configured and make sure they match with the credentials of the X-Pack user set up in Elasticsearch.

## Issue 5: Security is enabled in DXP, but X-Pack Security is disabled in Elasticsearch

**Issue 5 - DXP 7.3+: javax.net.ssl.SSLException: Unrecognized SSL message, plaintext connection?**

```
Caused by: java.io.IOException: Unrecognized SSL message, plaintext connection?
	at org.elasticsearch.client.RestClient.extractAndWrapCause(RestClient.java:854) ~[elasticsearch-rest-client-7.9.0.jar:7.9.0]
	at org.elasticsearch.client.RestClient.performRequest(RestClient.java:259) ~[elasticsearch-rest-client-7.9.0.jar:7.9.0]
	at org.elasticsearch.client.RestClient.performRequest(RestClient.java:246) ~[elasticsearch-rest-client-7.9.0.jar:7.9.0]
	at org.elasticsearch.client.RestHighLevelClient.internalPerformRequest(RestHighLevelClient.java:1613) ~[elasticsearch-rest-high-level-client-7.9.0.jar:7.9.0]
	at org.elasticsearch.client.RestHighLevelClient.performRequest(RestHighLevelClient.java:1583) ~[elasticsearch-rest-high-level-client-7.9.0.jar:7.9.0]
	at org.elasticsearch.client.RestHighLevelClient.performRequestAndParseEntity(RestHighLevelClient.java:1553) ~[elasticsearch-rest-high-level-client-7.9.0.jar:7.9.0]
	at org.elasticsearch.client.RestHighLevelClient.bulk(RestHighLevelClient.java:533) ~[elasticsearch-rest-high-level-client-7.9.0.jar:7.9.0]
	at com.liferay.portal.search.elasticsearch7.internal.search.engine.adapter.document.BulkDocumentRequestExecutorImpl.getBulkResponse(BulkDocumentRequestExecutorImpl.java:158) ~[bundleFile:?]
	... 55 more
Caused by: javax.net.ssl.SSLException: Unrecognized SSL message, plaintext connection?
	at sun.security.ssl.SSLEngineInputRecord.bytesInCompletePacket(SSLEngineInputRecord.java:146) ~[?:?]
	at sun.security.ssl.SSLEngineInputRecord.bytesInCompletePacket(SSLEngineInputRecord.java:64) ~[?:?]
	at sun.security.ssl.SSLEngineImpl.readRecord(SSLEngineImpl.java:557) ~[?:?]
	at sun.security.ssl.SSLEngineImpl.unwrap(SSLEngineImpl.java:454) ~[?:?]
	at sun.security.ssl.SSLEngineImpl.unwrap(SSLEngineImpl.java:433) ~[?:?]
	at javax.net.ssl.SSLEngine.unwrap(SSLEngine.java:637) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.doUnwrap(SSLIOSession.java:275) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.doHandshake(SSLIOSession.java:321) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.isAppInputReady(SSLIOSession.java:523) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.impl.nio.reactor.AbstractIODispatch.inputReady(AbstractIODispatch.java:120) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.readable(BaseIOReactor.java:162) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvent(AbstractIOReactor.java:337) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvents(AbstractIOReactor.java:315) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.execute(AbstractIOReactor.java:276) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.execute(BaseIOReactor.java:104) ~[httpcore-nio-4.4.12.jar:4.4.12]
	at org.apache.http.impl.nio.reactor.AbstractMultiworkerIOReactor$Worker.run(AbstractMultiworkerIOReactor.java:591) ~[httpcore-nio-4.4.12.jar:4.4.12]
	... 1 more
```

**Issue 5 - DXP 7.0-7.2: org.elasticsearch.client.transport.NoNodeAvailableException**

```
Caused by: java.lang.RuntimeException: org.elasticsearch.client.transport.NoNodeAvailableException: NoNodeAvailableException[None of the configured nodes are available: [{#transport#-1}{VvW6zLWlTWCyhbj2LqQKgA}{es-node1}{192.168.0.17:9300}]]
	at org.elasticsearch.client.transport.TransportClientNodesService.ensureNodesAreAvailable(TransportClientNodesService.java:352)
```

**Issue 5: Elasticsearch log**

```
[2021-06-07T17:48:31,554][WARN ][o.e.t.TcpTransport       ] [es-node1] SSL/TLS request received but SSL/TLS is not enabled on this node, got (16,3,3,1), [Netty4TcpChannel{localAddress=/192.168.0.17:9300, remoteAddress=/192.168.0.17:40646}], closing connection
```

#### Issue 5: Diagnosing & Resolution

Open `elasticsearch.yml` and make sure `xpack.security.enabled` is not set to `false` and the HTTP and Transport layers are also configured properly to use encrypted communication.

## Issue 6: DXP and the Elasticsearch nodes are using certificates signed by a different CA

When`*.ssl.verification_mode` is configured as `certificate` or `full` in `elasticsearch.yml` for the HTTP and/or Transport layer.

**Issue 6 - DXP 7.3+: `PKIX path validation failed: java.security.cert.CertPathValidatorException: Path does not chain with any of the trust anchors`**

```
Caused by: javax.net.ssl.SSLHandshakeException: PKIX path validation failed: java.security.cert.CertPathValidatorException: Path does not chain with any of the trust anchors
	at sun.security.ssl.Alert.createSSLException(Alert.java:131) ~[?:?]
	at sun.security.ssl.TransportContext.fatal(TransportContext.java:353) ~[?:?]
	at sun.security.ssl.TransportContext.fatal(TransportContext.java:296) ~[?:?]
	at sun.security.ssl.TransportContext.fatal(TransportContext.java:291) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.checkServerCerts(CertificateMessage.java:1356) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.onConsumeCertificate(CertificateMessage.java:1231) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.consume(CertificateMessage.java:1174) ~[?:?]
	at sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:392) ~[?:?]
	at sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:444) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1074) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1061) ~[?:?]
	at java.security.AccessController.doPrivileged(Native Method) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask.run(SSLEngineImpl.java:1008) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.doRunTask(SSLIOSession.java:285) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.doHandshake(SSLIOSession.java:345) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.isAppInputReady(SSLIOSession.java:523) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIODispatch.inputReady(AbstractIODispatch.java:120) ~[?:?]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.readable(BaseIOReactor.java:162) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvent(AbstractIOReactor.java:337) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvents(AbstractIOReactor.java:315) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.execute(AbstractIOReactor.java:276) ~[?:?]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.execute(BaseIOReactor.java:104) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractMultiworkerIOReactor$Worker.run(AbstractMultiworkerIOReactor.java:591) ~[?:?]
	... 1 more
Caused by: sun.security.validator.ValidatorException: PKIX path validation failed: java.security.cert.CertPathValidatorException: Path does not chain with any of the trust anchors
	at sun.security.validator.PKIXValidator.doValidate(PKIXValidator.java:369) ~[?:?]
	at sun.security.validator.PKIXValidator.engineValidate(PKIXValidator.java:275) ~[?:?]
	at sun.security.validator.Validator.validate(Validator.java:264) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.validate(X509TrustManagerImpl.java:313) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkTrusted(X509TrustManagerImpl.java:276) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkServerTrusted(X509TrustManagerImpl.java:141) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.checkServerCerts(CertificateMessage.java:1334) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.onConsumeCertificate(CertificateMessage.java:1231) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.consume(CertificateMessage.java:1174) ~[?:?]
	at sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:392) ~[?:?]
	at sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:444) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1074) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1061) ~[?:?]
	at java.security.AccessController.doPrivileged(Native Method) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask.run(SSLEngineImpl.java:1008) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.doRunTask(SSLIOSession.java:285) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.doHandshake(SSLIOSession.java:345) ~[?:?]
	at org.apache.http.nio.reactor.ssl.SSLIOSession.isAppInputReady(SSLIOSession.java:523) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIODispatch.inputReady(AbstractIODispatch.java:120) ~[?:?]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.readable(BaseIOReactor.java:162) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvent(AbstractIOReactor.java:337) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.processEvents(AbstractIOReactor.java:315) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractIOReactor.execute(AbstractIOReactor.java:276) ~[?:?]
	at org.apache.http.impl.nio.reactor.BaseIOReactor.execute(BaseIOReactor.java:104) ~[?:?]
	at org.apache.http.impl.nio.reactor.AbstractMultiworkerIOReactor$Worker.run(AbstractMultiworkerIOReactor.java:591) ~[?:?]
	... 1 more
Caused by: java.security.cert.CertPathValidatorException: Path does not chain with any of the trust anchors
	at sun.security.provider.certpath.PKIXCertPathValidator.validate(PKIXCertPathValidator.java:158) ~[?:?]
	at sun.security.provider.certpath.PKIXCertPathValidator.engineValidate(PKIXCertPathValidator.java:84) ~[?:?]
	at java.security.cert.CertPathValidator.validate(CertPathValidator.java:309) ~[?:?]
	at sun.security.validator.PKIXValidator.doValidate(PKIXValidator.java:364) ~[?:?]
	at sun.security.validator.PKIXValidator.engineValidate(PKIXValidator.java:275) ~[?:?]
	at sun.security.validator.Validator.validate(Validator.java:264) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.validate(X509TrustManagerImpl.java:313) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkTrusted(X509TrustManagerImpl.java:276) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkServerTrusted(X509TrustManagerImpl.java:141) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.checkServerCerts(CertificateMessage.java:1334) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.onConsumeCertificate(CertificateMessage.java:1231) ~[?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.consume(CertificateMessage.java:1174) ~[?:?]
	at sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:392) ~[?:?]
	at sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:444) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1074) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1061) ~[?:?]
```

**Issue 6 - DXP 7.0-7.2: `PKIX path validation failed: java.security.cert.CertPathValidatorException: Path does not chain with any of the trust anchors`**

Note: when `transportSSLVerificationMode="certificate"` is set in the `*.XPackSecurityConfiguration.config` file.

```
[2021-06-07T18:18:44,579][WARN ][o.e.c.s.DiagnosticTrustManager] [
ode_name]failed to establish trust with server at [<unknown host>]; the server provided a certificate with subject name [CN=elastic-nodes] and fingerprint [065071bd5b26e83b2903b09179acf4a48851d775]; the certificate has subject alternative names [DNS:localhost,DNS:dxp.example.com,DNS:es-node-1,IP:127.0.0.1,DNS:es-node2,DNS:es-node3,DNS:kibana.example.com]; the certificate is issued by [CN=elastic-ca]; the certificate is signed by (subject [CN=elastic-ca] fingerprint [39b9312498b37827bdf8f64faef397449c0c0686]) which is self-issued; the [CN=elastic-ca] certificate is not trusted in this ssl context ([xpack.security.transport.ssl]); this ssl context does trust a certificate with subject [CN=elastic-ca] but the trusted certificate has fingerprint [9d82c3b32af8607add6682b5b7f20f4357735bce]
sun.security.validator.ValidatorException: PKIX path validation failed: java.security.cert.CertPathValidatorException: Path does not chain with any of the trust anchors
	at sun.security.validator.PKIXValidator.doValidate(PKIXValidator.java:369) ~[?:?]
	at sun.security.validator.PKIXValidator.engineValidate(PKIXValidator.java:275) ~[?:?]
	at sun.security.validator.Validator.validate(Validator.java:264) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.validate(X509TrustManagerImpl.java:313) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkTrusted(X509TrustManagerImpl.java:276) ~[?:?]
	at sun.security.ssl.X509TrustManagerImpl.checkServerTrusted(X509TrustManagerImpl.java:141) ~[?:?]
	at org.elasticsearch.common.ssl.DiagnosticTrustManager.checkServerTrusted(DiagnosticTrustManager.java:110) [elasticsearch-ssl-config-7.9.0.jar:7.9.0]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.checkServerCerts(CertificateMessage.java:1334) [?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.onConsumeCertificate(CertificateMessage.java:1231) [?:?]
	at sun.security.ssl.CertificateMessage$T13CertificateConsumer.consume(CertificateMessage.java:1174) [?:?]
	at sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:392) [?:?]
	at sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:443) [?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1074) [?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask$DelegatedAction.run(SSLEngineImpl.java:1061) [?:?]
	at java.security.AccessController.doPrivileged(Native Method) ~[?:?]
	at sun.security.ssl.SSLEngineImpl$DelegatedTask.run(SSLEngineImpl.java:1008) [?:?]
	at io.netty.handler.ssl.SslHandler.runAllDelegatedTasks(SslHandler.java:1542) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.ssl.SslHandler.runDelegatedTasks(SslHandler.java:1556) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.ssl.SslHandler.unwrap(SslHandler.java:1440) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.ssl.SslHandler.decodeJdkCompatible(SslHandler.java:1267) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.ssl.SslHandler.decode(SslHandler.java:1314) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.codec.ByteToMessageDecoder.decodeRemovalReentryProtection(ByteToMessageDecoder.java:501) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.codec.ByteToMessageDecoder.callDecode(ByteToMessageDecoder.java:440) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.handler.codec.ByteToMessageDecoder.channelRead(ByteToMessageDecoder.java:276) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:379) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:365) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.fireChannelRead(AbstractChannelHandlerContext.java:357) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.DefaultChannelPipeline$HeadContext.channelRead(DefaultChannelPipeline.java:1410) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:379) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.AbstractChannelHandlerContext.invokeChannelRead(AbstractChannelHandlerContext.java:365) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.DefaultChannelPipeline.fireChannelRead(DefaultChannelPipeline.java:919) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.AbstractNioByteChannel$NioByteUnsafe.read(AbstractNioByteChannel.java:163) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKey(NioEventLoop.java:714) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKeysPlain(NioEventLoop.java:615) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.processSelectedKeys(NioEventLoop.java:578) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.channel.nio.NioEventLoop.run(NioEventLoop.java:493) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.util.concurrent.SingleThreadEventExecutor$4.run(SingleThreadEventExecutor.java:989) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at io.netty.util.internal.ThreadExecutorMap$2.run(ThreadExecutorMap.java:74) [netty-all-4.1.49.Final.jar:4.1.49.Final]
	at java.lang.Thread.run(Thread.java:829) [?:?]
Caused by: java.security.cert.CertPathValidatorException: Path does not chain with any of the trust anchors
	at sun.security.provider.certpath.PKIXCertPathValidator.validate(PKIXCertPathValidator.java:157) ~[?:?]
	at sun.security.provider.certpath.PKIXCertPathValidator.engineValidate(PKIXCertPathValidator.java:83) ~[?:?]
	at java.security.cert.CertPathValidator.validate(CertPathValidator.java:309) ~[?:?]
	at sun.security.validator.PKIXValidator.doValidate(PKIXValidator.java:364) ~[?:?]
	... 38 more
```

**Issue 6: Elasticsearch log**

In case of DXP 7.0-7.2 when connecting to the server over TCP:

```
[2021-06-07T18:19:49,623][WARN ][o.e.x.c.s.t.n.SecurityNetty4Transport] [es-node1] client did not trust this server's certificate, closing connection Netty4TcpChannel{localAddress=0.0.0.0/0.0.0.0:9300, remoteAddress=/192.168.0.17:41820}
```

### Issue 6: Diagnosing & Resolution

Make sure all nodes in your stack (DXP, Elasticsearch, Kibana) are using certificates signed by the same Certificate Authority (CA) and the certificate (public key) of the CA is present in the client's (DXP, Kibana) truststore/sslCertificateAuthoritiesPaths files. If you open your cert files, the "Issuer Name" or "Issued by" entry holds information about the issuer CA.

**Issue 7: Elasticsearch Monitoring/X-Pack Monitoring widget is temporarily unavailable due to certificate issues when Kibana is using HTTPS**

**Issue 7 - DXP 7.3+: `java.net.ConnectException: Connection refused`**

```
2021-06-08 13:54:53.084 ERROR [http-nio-8080-exec-8][MonitoringProxyServlet:107] java.net.ConnectException: Connection refused (Connection refused)
java.net.ConnectException: Connection refused (Connection refused)
	at java.net.PlainSocketImpl.socketConnect(Native Method) ~[?:?]
	at java.net.AbstractPlainSocketImpl.doConnect(AbstractPlainSocketImpl.java:399) ~[?:?]
	at java.net.AbstractPlainSocketImpl.connectToAddress(AbstractPlainSocketImpl.java:242) ~[?:?]
	at java.net.AbstractPlainSocketImpl.connect(AbstractPlainSocketImpl.java:224) ~[?:?]
	at java.net.SocksSocketImpl.connect(SocksSocketImpl.java:403) ~[?:?]
	at java.net.Socket.connect(Socket.java:608) ~[?:?]
	at sun.security.ssl.SSLSocketImpl.connect(SSLSocketImpl.java:287) ~[?:?]
	at org.apache.http.conn.ssl.SSLSocketFactory.connectSocket(SSLSocketFactory.java:532) ~[httpclient-4.5.jar:?]
	at org.apache.http.conn.ssl.SSLSocketFactory.connectSocket(SSLSocketFactory.java:409) ~[httpclient-4.5.jar:?]
	at org.apache.http.impl.conn.DefaultClientConnectionOperator.openConnection(DefaultClientConnectionOperator.java:177) ~[httpclient-4.5.jar:?]
	at org.apache.http.impl.conn.ManagedClientConnectionImpl.open(ManagedClientConnectionImpl.java:304) ~[httpclient-4.5.jar:?]
	at org.apache.http.impl.client.DefaultRequestDirector.tryConnect(DefaultRequestDirector.java:611) ~[httpclient-4.5.jar:?]
	at org.apache.http.impl.client.DefaultRequestDirector.execute(DefaultRequestDirector.java:446) ~[httpclient-4.5.jar:?]
	at org.apache.http.impl.client.AbstractHttpClient.doExecute(AbstractHttpClient.java:882) ~[httpclient-4.5.jar:?]
	at org.apache.http.impl.client.CloseableHttpClient.execute(CloseableHttpClient.java:117) ~[httpclient-4.5.jar:?]
	at org.apache.http.impl.client.CloseableHttpClient.execute(CloseableHttpClient.java:55) ~[httpclient-4.5.jar:?]
	at org.mitre.dsmiley.httpproxy.ProxyServlet.service(ProxyServlet.java:267) ~[smiley-http-proxy-servlet-1.7.jar:?]
	at com.liferay.portal.search.elasticsearch.monitoring.web.internal.servlet.MonitoringProxyServlet.service(MonitoringProxyServlet.java:224) [bundleFile:?]
```

**Issue 7 - DXP 7.0-7.2: `sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target`**

```
2021-06-08 13:24:57.104 ERROR [http-nio-7211-exec-8][XPackMonitoringProxyServlet:106] javax.net.ssl.SSLHandshakeException: PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
javax.net.ssl.SSLHandshakeException: PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
	at java.base/sun.security.ssl.Alert.createSSLException(Alert.java:131)
	at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:353)
	at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:296)
	at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:291)
	at java.base/sun.security.ssl.CertificateMessage$T12CertificateConsumer.checkServerCerts(CertificateMessage.java:654)
	at java.base/sun.security.ssl.CertificateMessage$T12CertificateConsumer.onCertificate(CertificateMessage.java:473)
	at java.base/sun.security.ssl.CertificateMessage$T12CertificateConsumer.consume(CertificateMessage.java:369)
	at java.base/sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:392)
	at java.base/sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:444)
	at java.base/sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:422)
	at java.base/sun.security.ssl.TransportContext.dispatch(TransportContext.java:183)
	at java.base/sun.security.ssl.SSLTransport.decode(SSLTransport.java:171)
	at java.base/sun.security.ssl.SSLSocketImpl.decode(SSLSocketImpl.java:1359)
	at java.base/sun.security.ssl.SSLSocketImpl.readHandshakeRecord(SSLSocketImpl.java:1268)
	at java.base/sun.security.ssl.SSLSocketImpl.startHandshake(SSLSocketImpl.java:401)
	at java.base/sun.security.ssl.SSLSocketImpl.startHandshake(SSLSocketImpl.java:373)
	at org.apache.http.conn.ssl.SSLSocketFactory.connectSocket(SSLSocketFactory.java:543)
	at org.apache.http.conn.ssl.SSLSocketFactory.connectSocket(SSLSocketFactory.java:409)
	at org.apache.http.impl.conn.DefaultClientConnectionOperator.openConnection(DefaultClientConnectionOperator.java:177)
	at org.apache.http.impl.conn.ManagedClientConnectionImpl.open(ManagedClientConnectionImpl.java:304)
	at org.apache.http.impl.client.DefaultRequestDirector.tryConnect(DefaultRequestDirector.java:611)
	at org.apache.http.impl.client.DefaultRequestDirector.execute(DefaultRequestDirector.java:446)
	at org.apache.http.impl.client.AbstractHttpClient.doExecute(AbstractHttpClient.java:882)
	at org.apache.http.impl.client.CloseableHttpClient.execute(CloseableHttpClient.java:117)
	at org.apache.http.impl.client.CloseableHttpClient.execute(CloseableHttpClient.java:55)
	at org.mitre.dsmiley.httpproxy.ProxyServlet.service(ProxyServlet.java:267)
	at com.liferay.portal.search.elasticsearch6.xpack.monitoring.web.internal.servlet.XPackMonitoringProxyServlet.service(XPackMonitoringProxyServlet.java:216)
	at javax.servlet.http.HttpServlet.service(HttpServlet.java:733)
	at org.eclipse.equinox.http.servlet.internal.registration.EndpointRegistration.service(EndpointRegistration.java:153)
	at org.eclipse.equinox.http.servlet.internal.servlet.ResponseStateHandler.processRequest(ResponseStateHandler.java:62)
	at org.eclipse.equinox.http.servlet.internal.context.DispatchTargets.doDispatch(DispatchTargets.java:120)
	at org.eclipse.equinox.http.servlet.internal.HttpServiceRuntimeImpl.doDispatch(HttpServiceRuntimeImpl.java:373)
	at org.eclipse.equinox.http.servlet.internal.servlet.ProxyServlet.service(ProxyServlet.java:70)
	at javax.servlet.http.HttpServlet.service(HttpServlet.java:733)
	at com.liferay.portal.module.framework.ModuleFrameworkServletAdapter.service(ModuleFrameworkServletAdapter.java:52)
	at javax.servlet.http.HttpServlet.service(HttpServlet.java:733)
	at org.apache.catalina.core.ApplicationFilterChain.internalDoFilter(ApplicationFilterChain.java:227)
	at org.apache.catalina.core.ApplicationFilterChain.doFilter(ApplicationFilterChain.java:162)
	at org.apache.tomcat.websocket.server.WsFilter.doFilter(WsFilter.java:53)
	at org.apache.catalina.core.ApplicationFilterChain.internalDoFilter(ApplicationFilterChain.java:189)
	at org.apache.catalina.core.ApplicationFilterChain.doFilter(ApplicationFilterChain.java:162)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:124)
	at com.liferay.portal.servlet.filters.password.modified.PasswordModifiedFilter.processFilter(PasswordModifiedFilter.java:62)
	at com.liferay.portal.kernel.servlet.BaseFilter.doFilter(BaseFilter.java:49)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDoFilter(InvokerFilterChain.java:215)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:116)
	at com.liferay.portal.servlet.filters.lockout.LockoutFilter.processFilter(LockoutFilter.java:58)
	at com.liferay.portal.kernel.servlet.BaseFilter.doFilter(BaseFilter.java:49)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDoFilter(InvokerFilterChain.java:215)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:116)
	at com.liferay.portal.kernel.servlet.BaseFilter.processFilter(BaseFilter.java:147)
	at com.liferay.portal.sharepoint.SharepointFilter.processFilter(SharepointFilter.java:88)
	at com.liferay.portal.kernel.servlet.BaseFilter.doFilter(BaseFilter.java:49)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDoFilter(InvokerFilterChain.java:215)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:116)
	at com.liferay.portal.kernel.servlet.BaseFilter.processFilter(BaseFilter.java:147)
	at com.liferay.portal.servlet.filters.virtualhost.VirtualHostFilter.processFilter(VirtualHostFilter.java:270)
	at com.liferay.portal.kernel.servlet.BaseFilter.doFilter(BaseFilter.java:49)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDoFilter(InvokerFilterChain.java:215)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:116)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDirectCallFilter(InvokerFilterChain.java:196)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:99)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDirectCallFilter(InvokerFilterChain.java:196)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:99)
	at org.tuckey.web.filters.urlrewrite.RuleChain.handleRewrite(RuleChain.java:176)
	at org.tuckey.web.filters.urlrewrite.RuleChain.doRules(RuleChain.java:145)
	at org.tuckey.web.filters.urlrewrite.UrlRewriter.processRequest(UrlRewriter.java:92)
	at org.tuckey.web.filters.urlrewrite.UrlRewriteFilter.doFilter(UrlRewriteFilter.java:389)
	at com.liferay.portal.servlet.filters.urlrewrite.UrlRewriteFilter.processFilter(UrlRewriteFilter.java:65)
	at com.liferay.portal.kernel.servlet.BaseFilter.doFilter(BaseFilter.java:49)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDoFilter(InvokerFilterChain.java:215)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:116)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDirectCallFilter(InvokerFilterChain.java:175)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:99)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDirectCallFilter(InvokerFilterChain.java:175)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:99)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.processDirectCallFilter(InvokerFilterChain.java:196)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilterChain.doFilter(InvokerFilterChain.java:99)
	at com.liferay.portal.kernel.servlet.filters.invoker.InvokerFilter.doFilter(InvokerFilter.java:104)
	at org.apache.catalina.core.ApplicationFilterChain.internalDoFilter(ApplicationFilterChain.java:189)
	at org.apache.catalina.core.ApplicationFilterChain.doFilter(ApplicationFilterChain.java:162)
	at org.apache.catalina.core.StandardWrapperValve.invoke(StandardWrapperValve.java:202)
	at org.apache.catalina.core.StandardContextValve.invoke(StandardContextValve.java:97)
	at org.apache.catalina.authenticator.AuthenticatorBase.invoke(AuthenticatorBase.java:542)
	at org.apache.catalina.core.StandardHostValve.invoke(StandardHostValve.java:143)
	at org.apache.catalina.valves.ErrorReportValve.invoke(ErrorReportValve.java:92)
	at org.apache.catalina.core.StandardEngineValve.invoke(StandardEngineValve.java:78)
	at org.apache.catalina.connector.CoyoteAdapter.service(CoyoteAdapter.java:346)
	at org.apache.coyote.http11.Http11Processor.service(Http11Processor.java:374)
	at org.apache.coyote.AbstractProcessorLight.process(AbstractProcessorLight.java:65)
	at org.apache.coyote.AbstractProtocol$ConnectionHandler.process(AbstractProtocol.java:887)
	at org.apache.tomcat.util.net.NioEndpoint$SocketProcessor.doRun(NioEndpoint.java:1684)
	at org.apache.tomcat.util.net.SocketProcessorBase.run(SocketProcessorBase.java:49)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1128)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:628)
	at org.apache.tomcat.util.threads.TaskThread$WrappingRunnable.run(TaskThread.java:61)
	at java.base/java.lang.Thread.run(Thread.java:834)
Caused by: sun.security.validator.ValidatorException: PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
	at java.base/sun.security.validator.PKIXValidator.doBuild(PKIXValidator.java:439)
	at java.base/sun.security.validator.PKIXValidator.engineValidate(PKIXValidator.java:306)
	at java.base/sun.security.validator.Validator.validate(Validator.java:264)
	at java.base/sun.security.ssl.X509TrustManagerImpl.validate(X509TrustManagerImpl.java:313)
	at java.base/sun.security.ssl.X509TrustManagerImpl.checkTrusted(X509TrustManagerImpl.java:222)
	at java.base/sun.security.ssl.X509TrustManagerImpl.checkServerTrusted(X509TrustManagerImpl.java:129)
	at java.base/sun.security.ssl.CertificateMessage$T12CertificateConsumer.checkServerCerts(CertificateMessage.java:638)
	... 92 more
Caused by: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
	at java.base/sun.security.provider.certpath.SunCertPathBuilder.build(SunCertPathBuilder.java:141)
	at java.base/sun.security.provider.certpath.SunCertPathBuilder.engineBuild(SunCertPathBuilder.java:126)
	at java.base/java.security.cert.CertPathBuilder.build(CertPathBuilder.java:297)
	at java.base/sun.security.validator.PKIXValidator.doBuild(PKIXValidator.java:434)
	... 98 more
```

**Issue 7 - Kibana log**

```
 error  [13:24:57.089] [error][client][connection] Error: 139942872246080:error:14094416:SSL routines:ssl3_read_bytes:sslv3 alert certificate unknown:../deps/openssl/openssl/ssl/record/rec_layer_s3.c:1544:SSL alert number 46
```

#### Issue 7: Diagnosing & Resolution

The above errors indicate that the server (Kibana) the client (DXP through the LES Monitoring widget) is probably using a self-signed certificate and the CA is not present in the client's trustStore file, which is the JDK's `cacerts` file by default.

Because you’re using the Monitoring portlet in Liferay as a proxy to Kibana’s UI and you are using a self-signed certificate, you must configure the application server’s startup JVM parameters to trust Kibana’s certificate.

One approach is to add the truststore path, password and type to your application server’s startup JVM parameters using the same files you also used to configure the Elasticsearch connector to use security. Here are example truststore and path parameters for appending to a Tomcat server’s `CATALINA_OPTS` through the `setenv.sh/bat` file:

```
CATALINA_OPTS="${CATALINA_OPTS} -Djavax.net.ssl.trustStore=/path/to/elastic-nodes.p12 -Djavax.net.ssl.trustStorePassword=liferay -Djavax.net.ssl.trustStoreType=pkcs12"
```

Another approach (recommended) is to make a copy of the default `cacerts` file (located in `JAVA_HOME/jre/lib/security` in JDK 8 or in `JAVA_HOME/lib/security` in JDK 11) , name it `cacerts-custom.jks`, extract/obtain the certificate of the CA without the private key using `openssl` (if you only have a single .p12 file like `elastic-stack-ca.p12`) and import it into your custom JKS file using Java's `keytool` and then configure Tomcat to use that trustStore:

```
CATALINA_OPTS="${CATALINA_OPTS} -Djavax.net.ssl.trustStore=/PATH/TO/cacerts-custom.jks -Djavax.net.ssl.trustStorePassword=changeit"
```

## Issue 8: "SSLException: No PSK available. Unable to resume" error is thrown and Elasticsearch Monitoring/X-Pack Monitoring widget is broken with Kibana 7.11+ (LES)

**Issue 8 - DXP 7.3+**
TBA 

**Issue 8 - DXP 7.1-7.2: `javax.net.ssl.SSLException: No PSK available. Unable to resume.`**

```
12:24:42,480 ERROR [http-nio-8080-exec-10][XPackMonitoringProxyServlet:108] javax.net.ssl.SSLPeerUnverifiedException: peer not authenticated
javax.net.ssl.SSLPeerUnverifiedException: peer not authenticated
	at java.base/sun.security.ssl.SSLSessionImpl.getPeerCertificates(SSLSessionImpl.java:526)
	at org.apache.http.conn.ssl.AbstractVerifier.verify(AbstractVerifier.java:112)
	<truncated for clarity>
        at org.apache.tomcat.util.net.NioEndpoint$SocketProcessor.doRun(NioEndpoint.java:1601)
	at org.apache.tomcat.util.net.SocketProcessorBase.run(SocketProcessorBase.java:49)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1128)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:628)
	at org.apache.tomcat.util.threads.TaskThread$WrappingRunnable.run(TaskThread.java:61)
	at java.base/java.lang.Thread.run(Thread.java:834)
12:24:42,483 ERROR [http-nio-8080-exec-4][XPackMonitoringProxyServlet:108] javax.net.ssl.SSLException: No PSK available. Unable to resume.
javax.net.ssl.SSLException: No PSK available. Unable to resume.
	at java.base/sun.security.ssl.Alert.createSSLException(Alert.java:129)
	at java.base/sun.security.ssl.Alert.createSSLException(Alert.java:117)
	at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:308)
	at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:264)
	at java.base/sun.security.ssl.TransportContext.fatal(TransportContext.java:255)
	at java.base/sun.security.ssl.ServerHello$T13ServerHelloConsumer.consume(ServerHello.java:1224)
	at java.base/sun.security.ssl.ServerHello$ServerHelloConsumer.onServerHello(ServerHello.java:984)
	at java.base/sun.security.ssl.ServerHello$ServerHelloConsumer.consume(ServerHello.java:872)
	at java.base/sun.security.ssl.SSLHandshake.consume(SSLHandshake.java:392)
	at java.base/sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:444)
	at java.base/sun.security.ssl.HandshakeContext.dispatch(HandshakeContext.java:421)
	at java.base/sun.security.ssl.TransportContext.dispatch(TransportContext.java:178)
	at java.base/sun.security.ssl.SSLTransport.decode(SSLTransport.java:164)
	at java.base/sun.security.ssl.SSLSocketImpl.decode(SSLSocketImpl.java:1152)
	at java.base/sun.security.ssl.SSLSocketImpl.readHandshakeRecord(SSLSocketImpl.java:1063)
	at java.base/sun.security.ssl.SSLSocketImpl.startHandshake(SSLSocketImpl.java:402)
	at org.apache.http.conn.ssl.SSLSocketFactory.connectSocket(SSLSocketFactory.java:543)
	at org.apache.http.conn.ssl.SSLSocketFactory.connectSocket(SSLSocketFactory.java:409)
	at
```

#### Issue 8: Diagnosing & resolution

https://help.liferay.com/hc/en-us/articles/360058158791#resolve or https://learn.liferay.com/dxp/latest/en/using-search/liferay-enterprise-search/monitoring-elasticsearch.html#troubleshooting-the-monitoring-setup.

## Issue 9: High CPU usage by Elasticsearch due to JDK-8209333

* DXP 7.3
* Elasticsearch 7.9+
* JDK 11

https://bugs.openjdk.java.net/browse/JDK-8209333. This was fixed with OpenJDK 11.0.8. 

Relevant part from the thread dump:

```
"HttpClient-5-Worker-0" (main), priority=5, id=2535, state=RUNNABLE
	java.base@11.0.5/sun.security.ssl.SSLEngineImpl.getHandshakeStatus(SSLEngineImpl.java:801)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate$Writer.needWrap(SSLFlowDelegate.java:877)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate$Writer.processData(SSLFlowDelegate.java:771)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate$Writer$WriterDownstreamPusher.run(SSLFlowDelegate.java:646)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SequentialScheduler$CompleteRestartableTask.run(SequentialScheduler.java:147)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SequentialScheduler$SchedulableTask.run(SequentialScheduler.java:198)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SequentialScheduler.runOrSchedule(SequentialScheduler.java:271)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SequentialScheduler.runOrSchedule(SequentialScheduler.java:224)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate$Writer.triggerWrite(SSLFlowDelegate.java:723)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate.doHandshake(SSLFlowDelegate.java:1038)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate.doClosure(SSLFlowDelegate.java:1124)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate$Reader.unwrapBuffer(SSLFlowDelegate.java:501)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate$Reader.processData(SSLFlowDelegate.java:392)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SSLFlowDelegate$Reader$ReaderDownstreamPusher.run(SSLFlowDelegate.java:264)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SequentialScheduler$SynchronizedRestartableTask.run(SequentialScheduler.java:175)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SequentialScheduler$CompleteRestartableTask.run(SequentialScheduler.java:147)
	platform/java.net.http@11.0.5/jdk.internal.net.http.common.SequentialScheduler$SchedulableTask.run(SequentialScheduler.java:198)
	java.base@11.0.5/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1128)
	java.base@11.0.5/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:628)
	java.base@11.0.5/java.lang.Thread.run(Thread.java:834)
```

There were 6 such threads and we did a `top -H -p <JVM's PID>` and notice that they were indeed eating all the CPU.

This is causing CPU to skyrocket at almost 100% but without any consequence to the end user. This is as if the JVM is going to constantly loop through that healthcheck whenever it is not busy doing anything else.

## Issue 10: java.io.IOException: parseAlgParameters failed: ObjectIdentifier() -- data isn't an object ID (tag = 48) when security is configured with a PKCS#12 file generated by newer JDK

**Issue 10 - Error DXP 7.3+**

```
09:30:55,298 ERROR [ServerService Thread Pool -- 106][ElasticsearchConnectionManager:93] bundle com.liferay.portal.search.elasticsearch7.impl:5.0.17 (670)[com.liferay.portal.search.elasticsearch7.internal.connection.ElasticsearchConnectionManager(1656)] : The activate method has thrown an exception
java.lang.RuntimeException: java.io.IOException: parseAlgParameters failed: ObjectIdentifier() -- data isn't an object ID (tag = 48)
        at com.liferay.portal.search.elasticsearch7.internal.connection.RestHighLevelClientFactory.createSSLContext(RestHighLevelClientFactory.java:172)
        at com.liferay.portal.search.elasticsearch7.internal.connection.RestHighLevelClientFactory.customizeHttpClient(RestHighLevelClientFactory.java:185)
        at org.elasticsearch.client.RestClientBuilder.createHttpClient(RestClientBuilder.java:215)
        at java.security.AccessController.doPrivileged(Native Method)
        at org.elasticsearch.client.RestClientBuilder.build(RestClientBuilder.java:191)
        at org.elasticsearch.client.RestHighLevelClient.<init>(RestHighLevelClient.java:287)
        at org.elasticsearch.client.RestHighLevelClient.<init>(RestHighLevelClient.java:279)
        at com.liferay.portal.search.elasticsearch7.internal.connection.RestHighLevelClientFactory.lambda$newRestHighLevelClient$0(RestHighLevelClientFactory.java:64)
        at com.liferay.portal.search.elasticsearch7.internal.util.ClassLoaderUtil.getWithContextClassLoader(ClassLoaderUtil.java:34)
        at com.liferay.portal.search.elasticsearch7.internal.connection.RestHighLevelClientFactory.newRestHighLevelClient(RestHighLevelClientFactory.java:63)
        at com.liferay.portal.search.elasticsearch7.internal.connection.ElasticsearchConnection.createRestHighLevelClient(ElasticsearchConnection.java:164)
        at com.liferay.portal.search.elasticsearch7.internal.connection.ElasticsearchConnection.connect(ElasticsearchConnection.java:64)
```

**Issue 10 - Diagnosing**

This can happen when the the `.p12` files was generated using `keytool` by a JDK from a higher major version than what DXP is running on. (For example, generating the certs using JDK11, but than running the portal with JDK8.

#### Issue 10 - Resolution/Workaround

A.) Re-generate the certificate(s) using the same version of JDK that is used by DXP.  
B.) Use `JKS` format instead of `PKCS12` for the keystore  
C.) Use the `-Dkeystore.pkcs12.legacy` option with keytool to set the `keystore.pkcs12.legacy` system property and force OpenJDK 11/16's keytool to use the older algorithms (which are supported by Java 8 and 11)  

**Issue 10 - Related**

* https://stackoverflow.com/questions/67766268/ioexception-in-java-8-when-reading-pkcs12-keystore-created-with-keytool-from-ope
* https://bugs.java.com/bugdatabase/view_bug.do?bug_id=8202837
* https://bugs.java.com/bugdatabase/view_bug.do?bug_id=8267837
* https://liferay.slack.com/archives/CKY6GP7BL/p1634911737006400

## Troubleshooting Indexing & Searching Issues

### Issue 1: Stuck reindex: How to check the progress of a reindex process and remove blocked BackgroundTask and Lock records

https://help.liferay.com/hc/en-us/articles/360045141191

## Troubleshooting Issues with Sidecar & Embedded Mode

https://learn.liferay.com/dxp/7.x/en/using-search/installing-and-upgrading-a-search-engine/elasticsearch/using-the-sidecar-or-embedded-elasticsearch.html#embedded-versus-sidecar

### Issue 1: Error when trying to connect to Sidecar Elasticsearch 7.9 server from Kibana

While it’s not a supported production configuration, installing Kibana to monitor the bundled Elasticsearch server is useful during development and testing. Just be aware that you must install the [OSS only](https://www.elastic.co/downloads/kibana-oss) Kibana build.


<!--
Other:
* sidecar errors
* sidecar in Docker
* embedded errors
* tba

Examples:
* https://liferay.slack.com/archives/CKY6GP7BL/p1623139224144000
* https://liferay.slack.com/archives/CKY6GP7BL/p1623881099217200
* https://liferay.slack.com/archives/CKY6GP7BL/p1598909647002800
* https://liferay.slack.com/archives/CKY6GP7BL/p1611233043006800

-->

## Logging & Insights


### Getting the search query for Search Bar searches

Use the Search Insights widget, see https://learn.liferay.com/dxp/latest/en/using-search/search-pages-and-widgets/search-insights.html.

### Getting the search query for other kinds of index-based searches

You can get it by setting the log level for `om.liferay.portal.search.elasticsearch7.internal.ElasticsearchIndexSearcher` to `INFO` level in the Server Admin. And format the Elasticsearch JSON with https://jsonformatter.curiousconcept.com for example.

If you are on 7.1-7.2 and using ES6 (ootb), change the version in the package name from `7` to `6`.
If you are on 7.0 and using ES2 (ootb), remove the version from the package name.

----

* Packages names & levels
* connector config -> set `logExceptionsOnly="false"`
### Verbose ssl logging for diagnosing encryption related issues
* Hint: To enabling verbose SSL logging for DXP, you can add `CATALINA_OPTS="$CATALINA_OPTS -Djavax.net.debug=ssl:handshake:verbose"` to setenv.sh
* Hint: To enabling verbose SSL logging for Elasticsearch, add `-Djavax.net.debug=ssl:handshake:verbose` to the end of `$ES_HOME/config/jvm.options`.
