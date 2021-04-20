# liferay-search-configs
Collection of example configs and certs for quick local testing, workshops and [docs](https://learn.liferay.com/dxp/7.x/en/using_search.html). See further details [here](https://grow.liferay.com/learn/Search+Workshops+SUHU+Notes+-+Elastic+Stack+Overview#Avoiding-the-Chaos-with-Structure).

## Introduction

As there are so many possible setup combinations and versions, people can easily lost in the required configurations so they start mixing different properties. Some may not cause any harms, they are ignored/useless in a given context, but you can also screw up your environment with misconfiguration.

A common way people start managing this is to keep the configurations for each version and setup, separately. While it certainly works, it creates a lot of redundant files and does not help with understanding the "bigger picture" better.

So how to tackle with this?

1. Separate by Elastic Stack major version: with some very rare exceptions, properties are not changing within a major version which allows narrowing down the variants to a few. In addition, it also determines which config files you will need to use for Liferay DXP:
    * [ES 2.x]
    * ES 6.x
    * ES 7.x
    * [ES 7.x]
      etc.
1. Organize the files by their scope
1. Leverage configs which are (mostly/historically) version-less
1. Prefer comments and commented blocks within the config files over separate files  
    * It's easy to have comment blocks in elasticsearch.yml and kibana.yml so you can switch between different setups easily  
    * Liferay's OSGi .config files can also have comment blocks, however it's much sensitive to where they can be placed so sometimes it's still better to create a separate file
1. Don't be afraid of restarting from scratch
        Problems can happen any time, so prepare for wiping out your Elasticsearch nodes and start over from scratch. It really takes only a few steps to get to the point where you left previously.
