## EKS Kubernetes Information Collector

This is created to collect general and overall information related to kubernetes in Amazon EKS cluster for troubleshooting Amazon EKS customer support cases.

### Prerequisite

In order to run this script successfully:
1. Install [Kubectl utility](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html) and configure [KUBECONFIG](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html) on local machine prior to executing this script.
2. Set the `kubectl` context to desired cluster

### Usage

At a high level, this script can be executed in local terminal against the desired EKS cluster and it will collect general and overall information. The user will have an option to create a Tarball (Archive) bundle of collected information.

:warning: ***NOTE:***
+ The script requires at least Read-only permissions (RBAC) to capture the kubernetes resource manifests
+ The script will create a folder under your current working directory ($PWD) with your EKS cluster name and timestamp - **<EKS_Cluster_Name>_<Current_Timestamp_UTC>**. Please delete/remove the folder and corresponding archive file after sharing it with AWS Support.

```
curl -O https://raw.githubusercontent.com/aws-samples/sample-eks-k8s-information-collector/main/eks-k8s-information-collector.sh
bash eks-k8s-information-collector.sh
```

### Examples

#### Example 1 : Get help

```
$ bash eks-k8s-information-collector.sh -h
Usage: bash eks-k8s-information-collector.sh
your bundled logs will be located in ./<Cluster_Name_Start_Timestamp>.tar.gz
```

#### Example 2 : To collect general kubernetes infomation and create Archived (Tarball) file

```
$ bash eks-k8s-information-collector.sh
Trying to collect cluster info...
Trying to collect all objects list...
Trying to collect specific objects details...
Trying to collect events...
Done... your bundled logs are located in <Cluster_Name_Start_Timestamp>.tar.gz
```

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

