####################################
Developers
   |
   v
ADF Studio - -test01
   |
   v
GitHub repo - adftestgithub
   |
   v
main branch
   |
   v
Publish from ADF Studio
   |
   v
adf_publish branch with ARM templates
   |
   v
Azure DevOps Pipeline
   |
   v
Deploy to Prod ADF or Prod-DR or Test-DR





###################################################
Git
│
├── ARMTemplateForFactory.json
├── ARMTemplateParametersForFactory.json
│
├── cicd
│   └── azure-pipelines-adf-prod.yml
│
├── parameters
│   └── prod.parameters.json
│
└── scripts
    └── PrePostDeploymentScript.Ver2.ps1










###################################################
A. Azure Data Factory resources

You need:

Test ADF: mk-test01
Prod ADF: mk-prod-01
Prod resource group name
Azure subscription ID
Region/location of the prod resource group
B. GitHub repository

Your GitHub repo adftestpipeline should have:

Collaboration branch, usually main
Publish branch, usually adf_publish
ADF-generated files like:
ARMTemplateForFactory.json
ARMTemplateParametersForFactory.json