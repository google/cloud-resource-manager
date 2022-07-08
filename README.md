# Cloud Resource Manager (via gcloud)

Before deleting a Google Workspace account, the super admin must first delete all associated Google Cloud projects, folders, and Access Context Manager policies. If you want to find resources associated with your Cloud organization, you can either go to console.cloud.google.com > IAM & Admin > Manage Resources, OR use this script to programmatically interact with your resources.  The super admin will need the Organization Administrator, Folder Admin, Project Deleter, and Policy Editor Roles to modify project, folder, and policy resources.

Furthermore if your Cloud organization has Apps Script Projects, you need to delete them along with other Cloud projects before you can delete the Google Workspace account. The most common associated error message is:

```
"You have active projects in Google Cloud Platform. You need to delete all GCP projects before you can delete this account"
```

If used correctly, the script will first bind the necessary IAM permissions to your user, then guide you through deletions/restorations.


See [go/releasing](http://go/releasing) (available externally at
https://opensource.google/docs/releasing/) for more information about
releasing a new Google open source project.

This template uses the Apache license, as is Google's default.  See the
documentation for instructions on using alternate license.

## Source Code Headers

Every file containing source code must include copyright and license
information. This includes any JS/CSS files that you might be serving out to
browsers. (This is to help well-intentioned people avoid accidental copying that
doesn't comply with the license.)

Apache header:

    Copyright 2022 Google LLC

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
