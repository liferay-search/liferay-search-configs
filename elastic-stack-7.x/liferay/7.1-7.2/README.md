## Description

* `com.liferay.portal.bundle.blacklist.internal.BundleBlacklistConfiguration.config`

    To disable the bundled Elasticsearch 6.x connector and any additional incompatible modules.

* `com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config`

    with commented lines for multiple nodes - both for localhost and production mode setups

* `com.liferay.portal.search.elasticsearch7.configuration.XPackSecurityConfiguration.config`

    with commented/uncommented lines for PEM and PKCS#12

* `/pki` (TBA)

    * `com.liferay.portal.search.elasticsearch7.configuration.XPackSecurityConfiguration.config`
    
        with commented/uncommented lines for PEM and PKCS#12

* `com.liferay.portal.search.elasticsearch6.xpack.monitoring.web.internal.configuration.XPackMonitoringConfiguration.config`

    with commented line when Kibana is running on HTTPS
