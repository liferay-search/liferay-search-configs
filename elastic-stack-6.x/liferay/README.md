Files have to be placed in `[Liferay Home]/osgi/configs`, preferably before starting up the portal unless indicated otherwise.

## Description 

* `com.liferay.portal.bundle.blacklist.internal.BundleBlacklistConfiguration.config`

    for DXP 7.0 only

* `com.liferay.portal.search.elasticsearch6.configuration.ElasticsearchConfiguration.config`

    with commented lines for a multi node setup - both for localhost and production mode clusters

* `com.liferay.portal.search.elasticsearch6.xpack.security.internal.configuration.XPackSecurityConfiguration.config`

    with commented/uncommented lines for PEM and PKCS#12
