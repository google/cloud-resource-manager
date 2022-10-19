# Cloud Resource Manager (via gcloud)

Before deleting a Google Workspace account, the super admin must first delete all associated Google Cloud projects, folders, and Access Context Manager policies. If you want to find resources associated with your Cloud organization, you can either go to console.cloud.google.com > IAM & Admin > Manage Resources, OR use this script to programmatically interact with your resources.  The super admin will need the Organization Administrator, Folder Admin, Project Deleter, and Policy Editor Roles to modify project, folder, and policy resources.

Furthermore if your Cloud organization has Apps Script Projects, you need to delete them along with other Cloud projects before you can delete the Google Workspace account. The most common associated error message is:

```
"You have active projects in Google Cloud Platform. You need to delete all GCP projects before you can delete this account"
```

If used correctly, the script will first bind the necessary IAM permissions to your user, then guide you through deletions/restorations.

To use this script, run the following from a cloud shell instance:
```
git clone https://github.com/google/cloud-resource-manager.git 
bash cloud-resource-manager/cloud-resource-manager.sh
```
