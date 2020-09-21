---
stage: Enablement
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#designated-technical-writers
---

# Reference architecture: up to 1,000 users **(CORE ONLY)**

This page describes GitLab reference architecture for up to 1,000 users. For a
full list of reference architectures, see
[Available reference architectures](index.md#available-reference-architectures).

If you need to serve up to 1,000 users and you don't have strict availability
requirements, a single-node solution with
[frequent backups](index.md#automated-backups) is appropriate for
many organizations .

> - **Supported users (approximate):** 1,000
> - **High Availability:** No

| Users        | Configuration           | GCP            | AWS             | Azure          |
|--------------|-------------------------|----------------|-----------------|----------------|
| Up to 500    | 4 vCPU, 3.6GB memory    | n1-highcpu-4   | c5.xlarge       | F4s v2         |
| Up to 1,000  | 8 vCPU, 7.2GB memory    | n1-highcpu-8   | c5.2xlarge      | F8s v2         |

The Google Cloud Platform (GCP) architectures were built and tested using the
[Intel Xeon E5 v3 (Haswell)](https://cloud.google.com/compute/docs/cpu-platforms)
CPU platform. On different hardware you may find that adjustments, either lower
or higher, are required for your CPU or node counts. For more information, see
our [Sysbench](https://github.com/akopytov/sysbench)-based
[CPU benchmark](https://gitlab.com/gitlab-org/quality/performance/-/wikis/Reference-Architectures/GCP-CPU-Benchmarks).

In addition to the stated configurations, we recommend having at least 2GB of
swap on your server, even if you currently have enough available memory. Having
swap will help reduce the chance of errors occurring if your available memory
changes. We also recommend configuring the kernel's swappiness setting to a
lower value (such as `10`) to make the most of your memory, while still having
the swap available when needed.

## Setup instructions

For this default reference architecture, to install GitLab use the standard
[installation instructions](../../install/README.md).

NOTE: **Note:**
You can also optionally configure GitLab to use an
[external PostgreSQL service](../postgresql/external.md) or an
[external object storage service](../high_availability/object_storage.md) for
added performance and reliability at a reduced complexity cost.