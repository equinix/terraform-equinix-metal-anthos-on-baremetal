# Pure Storage Portworx installation

Portworx by Pure Storage is a distributed and high available data storage that takes advantage of the local and attached storage provided on each Equinix Metal device.  Portworx includes a [Container Storage Interface (CSI)](https://kubernetes-csi.github.io/docs/) driver.

Portworx differentiates between device disks using priority labels that can be applied to create distinct `StorageClasses`. See [Portworx: Dynamic Provisioning](https://docs.portworx.com/portworx-install-with-kubernetes/storage-operations/create-pvcs/dynamic-provisioning/) for more details.

Login to any one of the Anthos cluster nodes and run `pxctl status` to check the state of the Portworx services.

You can also use the Kubernetes API to check the status:

```sh
kubectl get pods -lapp=portworx -n kube-system
```

Portworx logs can be viewed by running:

```sh
kubectl logs -lapp=portworx -n kube-system --all-containers
```

By default, Portworx 2.6 is installed in the Anthos Cluster. The version of Portworx can be changed using the `portworx_version` variable.

## Licensing

Portworx is installed with a Trial license. To continue use at the end of the trial period, you will need a Portworx Enterprise Metal license.

More information about these licenses, their restrictions and enablement can be found at <https://docs.portworx.com/reference/knowledge-base/px-licensing/>.

To active the Portworx license through this module:

* Set the `portworx_license` variable to your license key
* Run `terraform apply`
