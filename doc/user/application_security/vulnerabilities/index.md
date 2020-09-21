---
type: reference, howto
stage: Secure
group: Threat Insights
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#designated-technical-writers
---

# Vulnerability Pages

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/13561) in [GitLab Ultimate](https://about.gitlab.com/pricing/) 13.0.

Each security vulnerability in a project's [Security Dashboard](../security_dashboard/index.md#project-security-dashboard) has an individual page which includes:

- Details of the vulnerability.
- The status of the vulnerability within the project.
- Available actions for the vulnerability.

On the vulnerability page, you can interact with the vulnerability in
several different ways:

- [Change the Vulnerability Status](#changing-vulnerability-status) - You can change the
  status of a vulnerability to **Detected**, **Confirmed**, **Dismissed**, or **Resolved**.
- [Create issue](#creating-an-issue-for-a-vulnerability) - Create a new issue with the
  title and description pre-populated with information from the vulnerability report.
  By default, such issues are [confidential](../../project/issues/confidential_issues.md).
- [Solution](#automatic-remediation-for-vulnerabilities) - For some vulnerabilities,
  a solution is provided for how to fix the vulnerability.

## Changing vulnerability status

You can switch the status of a vulnerability using the **Status** dropdown to one of
the following values:

| Status    | Description                                                       |
|-----------|-------------------------------------------------------------------|
| Detected  | The default state for a newly discovered vulnerability            |
| Confirmed | A user has seen this vulnerability and confirmed it to be real    |
| Dismissed | A user has seen this vulnerability and dismissed it               |
| Resolved  | The vulnerability has been fixed and is no longer in the codebase |

## Creating an issue for a vulnerability

You can create an issue for a vulnerability by selecting the **Create issue** button.

This creates a [confidential issue](../../project/issues/confidential_issues.md) in the
project the vulnerability came from, and pre-populates it with useful information from
the vulnerability report. After the issue is created, GitLab redirects you to the
issue page so you can edit, assign, or comment on the issue.

## Automatic remediation for vulnerabilities

You can fix some vulnerabilities by applying the solution that GitLab automatically
generates for you. [Read more about the automatic remediation for vulnerabilities feature](../index.md#solutions-for-vulnerabilities-auto-remediation).