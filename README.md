Docker for HPC
=======
----------
Docker containers can be used to package HPC applications with all their dependencies which simplifies HPC system configuration. As a result, HPC systems can be used to run much more application without reconfiguring the system. In addition, this strengthen the security and relieve the regular security patching.

Nevertheless, HPC systems also have their differences, which makes HPC system admins uncertain Docker is useful for HPC. The main concerns are the compute resources interconnect such as Infiniband and the message passing interface (MPI).

In this work, we are showing how Docker can be used to run workloads utilizing Infiniband and MPI. In addition, we are showing how users can start containers under their unique names and groups to access their network file systems for IO without the help of HPC schedulers such as Grid Engine or Slurm. Our solution consists of job launcher script and ssh client hack to support starting MPI processes in remote hosts without the need to start ssh server in each Docker containers.

**User Access and Network Filesystems**

To start the workload under a specific user, our launcher script build custom passwd and group file by pulling the user information from NIS then passes the resulted files in the Docker run command. Same concept can be used for any directory service such as ldap and IPA. Since the user is now available to the container, we start the workload using “su $USER –c” command. Below is an example for Docker run command that maps the user’s home directory, passwd, group file and starts ls command under that user privilege. User home directory is a network filesystem mounted to the host and we use –v to map it to the container so that the user has access to his regular environment.

	Docker run –v /home:/home -v ~/docker/passwd:/etc/passwd -v ~/docker/group:/etc/group DockerLocalRegistryServer:5000/imageName:imageTag su - $USER –c ls

**Infiniband Interconnect**
Since Docker containers are using the host kernel, all what is needed to access Infiniband is to map the device and install the user space driver. For this, we have built a repo that contains the user space drivers and use this repo during the time of building the Docker image. Sample DockerFile is included in this repo. Below is how we map the infiniband device:

	docker run --privileged --device=/dev/infiniband:/dev/infiniband –v /home:/home -v ~/docker/passwd:/etc/passwd -v ~/docker/group:/etc/group DockerLocalRegistryServer:5000/imageName:imageTag su - $USER –c ls


**MPI Workload**
MPI is the most common middleware used by most HPC applications to facilitate inter-processes communication. Different MPI implementations are available such as Openmpi and Mvapich and all are following the same standard. 
MPI commonly uses ssh to instantiate MPI workload using the available network with TCP/IP support then switches to Infiniband for all following communications. This causes a problem when using Docker, especially when you don’t want to start ssh server in each of your Docker containers. To solve this problem, we have written a wrapper for ssh client and included that wrapper in our Docker images.

Our launcher script starts the master MPI process in a container then the ssh wrapper script appends Docker run command to whatever command originally passed to ssh. The ssh wrapper script also takes care of cases where the MPI process tries to ssh to the localhost to start other MPI processes locally. 

For this to work, we use --net=host flag which forces the containers to share the same IP address as the host which makes the communication using ssh to a remote hosts possible. --ipc=host flag is also needed to allow inter-process communication via shared memory. The ssh wrapper script is included in this repo. Below is the docker run command after adding the needed additional flags.

	docker run --privileged --ipc=host --net=host --device=/dev/infiniband:/dev/infiniband –v /home:/home -v ~/docker/passwd:/etc/passwd -v ~/docker/group:/etc/group DockerLocalRegistryServer:5000/imageName:imageTag su - $USER –c  ~/docker/master_command


Below is an example of how to build and use an image to run simple MPI test.

<pre>
[ahmed.bukhamsin@myserver23 ~/docker-ib-mpi/ib_mpi:master] $ docker build -t myserver19:5000/rhel7:ib_mpi .
Sending build context to Docker daemon 6.656 kB
Step 1 : FROM myserver19:5000/rhel7
 ---> 1a9b3357bac5
Step 2 : MAINTAINER Ahmed Bu-khamsin <ahmed.bukhamsin@aramco.com>
 ---> Running in 8009d94cc38b
 ---> 0d467aa1255e
Removing intermediate container 8009d94cc38b
Step 3 : LABEL Description "Minimal RHEL7.2 with Infiniband and MPI support"
 ---> Running in 43c6a171a46e
 ---> 51165618a64b
Removing intermediate container 43c6a171a46e
Step 4 : ADD ib_repo.repo /etc/yum.repos.d/
 ---> b3b73279411f
Removing intermediate container e60d9890dcd1
Step 5 : ADD RHEL7.2_updated.repo /etc/yum.repos.d/
 ---> c5bd7cd67893
Removing intermediate container 031397ce0c89
Step 6 : RUN yum -y install libipathverbs openmpi_gcc_qlc mvapich2_gcc_qlc hostname
 ---> Running in 37b2185e77cc
Loaded plugins: ovl, product-id, search-disabled-repos, subscription-manager
This system is not registered to Red Hat Subscription Management. You can use subscription-manager to register.
Resolving Dependencies
--> Running transaction check
---> Package hostname.x86_64 0:3.13-3.el7 will be installed
---> Package libipathverbs.x86_64 0:1.3-1 will be installed
--> Processing Dependency: libibverbs.so.1(IBVERBS_1.0)(64bit) for package: libipathverbs-1.3-1.x86_64
--> Processing Dependency: libibverbs.so.1(IBVERBS_1.1)(64bit) for package: libipathverbs-1.3-1.x86_64
--> Processing Dependency: libibverbs.so.1()(64bit) for package: libipathverbs-1.3-1.x86_64
---> Package mvapich2_gcc_qlc.x86_64 0:2.1-1 will be installed
--> Processing Dependency: librdmacm for package: mvapich2_gcc_qlc-2.1-1.x86_64
--> Processing Dependency: libibumad for package: mvapich2_gcc_qlc-2.1-1.x86_64
---> Package openmpi_gcc_qlc.x86_64 0:1.10.0-1 will be installed
--> Processing Dependency: libgomp.so.1(GOMP_1.0)(64bit) for package: openmpi_gcc_qlc-1.10.0-1.x86_64
--> Processing Dependency: libgomp.so.1(OMP_1.0)(64bit) for package: openmpi_gcc_qlc-1.10.0-1.x86_64
--> Processing Dependency: mpi-selector for package: openmpi_gcc_qlc-1.10.0-1.x86_64
--> Processing Dependency: libquadmath.so.0()(64bit) for package: openmpi_gcc_qlc-1.10.0-1.x86_64
--> Processing Dependency: libgfortran.so.3()(64bit) for package: openmpi_gcc_qlc-1.10.0-1.x86_64
--> Processing Dependency: libosmcomp.so.3()(64bit) for package: openmpi_gcc_qlc-1.10.0-1.x86_64
--> Processing Dependency: libpsm_infinipath.so.1()(64bit) for package: openmpi_gcc_qlc-1.10.0-1.x86_64
--> Processing Dependency: libgomp.so.1()(64bit) for package: openmpi_gcc_qlc-1.10.0-1.x86_64
--> Running transaction check
---> Package infinipath-libs.x86_64 0:3.3-75029.1218_rhel7_qlc will be installed
---> Package libgfortran.x86_64 0:4.8.5-4.el7 will be installed
---> Package libgomp.x86_64 0:4.8.5-4.el7 will be installed
---> Package libibumad.x86_64 0:1.3.10.2-1.3.10.2 will be installed
---> Package libibverbs.x86_64 0:1.1.8-1 will be installed
---> Package libquadmath.x86_64 0:4.8.5-4.el7 will be installed
---> Package librdmacm.x86_64 0:1.0.21-1 will be installed
---> Package mpi-selector.x86_64 0:1.0.3-1 will be installed
--> Processing Dependency: perl(Text::Wrap) for package: mpi-selector-1.0.3-1.x86_64
--> Processing Dependency: /bin/csh for package: mpi-selector-1.0.3-1.x86_64
--> Processing Dependency: perl(Getopt::Long) for package: mpi-selector-1.0.3-1.x86_64
--> Processing Dependency: perl(File::Copy) for package: mpi-selector-1.0.3-1.x86_64
--> Processing Dependency: perl(strict) for package: mpi-selector-1.0.3-1.x86_64
---> Package opensm-libs.x86_64 0:3.3.19-3.3.19 will be installed
--> Running transaction check
---> Package perl.x86_64 4:5.16.3-286.el7 will be installed
--> Processing Dependency: perl-libs = 4:5.16.3-286.el7 for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Socket) >= 1.3 for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Scalar::Util) >= 1.10 for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl-macros for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl-libs for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(threads::shared) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(threads) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(constant) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Time::Local) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Time::HiRes) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Storable) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Socket) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Scalar::Util) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Pod::Simple::XHTML) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Pod::Simple::Search) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Filter::Util::Call) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(File::Temp) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(File::Spec::Unix) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(File::Spec::Functions) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(File::Spec) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(File::Path) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Exporter) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Cwd) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: perl(Carp) for package: 4:perl-5.16.3-286.el7.x86_64
--> Processing Dependency: libperl.so()(64bit) for package: 4:perl-5.16.3-286.el7.x86_64
---> Package perl-Getopt-Long.noarch 0:2.40-2.el7 will be installed
--> Processing Dependency: perl(Pod::Usage) >= 1.14 for package: perl-Getopt-Long-2.40-2.el7.noarch
--> Processing Dependency: perl(Text::ParseWords) for package: perl-Getopt-Long-2.40-2.el7.noarch
---> Package tcsh.x86_64 0:6.18.01-8.el7 will be installed
--> Running transaction check
---> Package perl-Carp.noarch 0:1.26-244.el7 will be installed
---> Package perl-Exporter.noarch 0:5.68-3.el7 will be installed
---> Package perl-File-Path.noarch 0:2.09-2.el7 will be installed
---> Package perl-File-Temp.noarch 0:0.23.01-3.el7 will be installed
---> Package perl-Filter.x86_64 0:1.49-3.el7 will be installed
---> Package perl-PathTools.x86_64 0:3.40-5.el7 will be installed
---> Package perl-Pod-Simple.noarch 1:3.28-4.el7 will be installed
--> Processing Dependency: perl(Pod::Escapes) >= 1.04 for package: 1:perl-Pod-Simple-3.28-4.el7.noarch
--> Processing Dependency: perl(Encode) for package: 1:perl-Pod-Simple-3.28-4.el7.noarch
---> Package perl-Pod-Usage.noarch 0:1.63-3.el7 will be installed
--> Processing Dependency: perl(Pod::Text) >= 3.15 for package: perl-Pod-Usage-1.63-3.el7.noarch
--> Processing Dependency: perl-Pod-Perldoc for package: perl-Pod-Usage-1.63-3.el7.noarch
---> Package perl-Scalar-List-Utils.x86_64 0:1.27-248.el7 will be installed
---> Package perl-Socket.x86_64 0:2.010-3.el7 will be installed
---> Package perl-Storable.x86_64 0:2.45-3.el7 will be installed
---> Package perl-Text-ParseWords.noarch 0:3.29-4.el7 will be installed
---> Package perl-Time-HiRes.x86_64 4:1.9725-3.el7 will be installed
---> Package perl-Time-Local.noarch 0:1.2300-2.el7 will be installed
---> Package perl-constant.noarch 0:1.27-2.el7 will be installed
---> Package perl-libs.x86_64 4:5.16.3-286.el7 will be installed
---> Package perl-macros.x86_64 4:5.16.3-286.el7 will be installed
---> Package perl-threads.x86_64 0:1.87-4.el7 will be installed
---> Package perl-threads-shared.x86_64 0:1.43-6.el7 will be installed
--> Running transaction check
---> Package perl-Encode.x86_64 0:2.51-7.el7 will be installed
---> Package perl-Pod-Escapes.noarch 1:1.04-286.el7 will be installed
---> Package perl-Pod-Perldoc.noarch 0:3.20-4.el7 will be installed
--> Processing Dependency: perl(parent) for package: perl-Pod-Perldoc-3.20-4.el7.noarch
--> Processing Dependency: perl(HTTP::Tiny) for package: perl-Pod-Perldoc-3.20-4.el7.noarch
--> Processing Dependency: groff-base for package: perl-Pod-Perldoc-3.20-4.el7.noarch
---> Package perl-podlators.noarch 0:2.5.1-3.el7 will be installed
--> Running transaction check
---> Package groff-base.x86_64 0:1.22.2-8.el7 will be installed
---> Package perl-HTTP-Tiny.noarch 0:0.033-3.el7 will be installed
---> Package perl-parent.noarch 1:0.225-244.el7 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package              Arch   Version                  Repository           Size
================================================================================
Installing:
 hostname             x86_64 3.13-3.el7               HPCGRHEL7.2_updated  17 k
 libipathverbs        x86_64 1.3-1                    IB_REPO              15 k
 mvapich2_gcc_qlc     x86_64 2.1-1                    IB_REPO             3.4 M
 openmpi_gcc_qlc      x86_64 1.10.0-1                 IB_REPO              17 M
Installing for dependencies:
 groff-base           x86_64 1.22.2-8.el7             HPCGRHEL7.2_updated 942 k
 infinipath-libs      x86_64 3.3-75029.1218_rhel7_qlc IB_REPO             698 k
 libgfortran          x86_64 4.8.5-4.el7              HPCGRHEL7.2_updated 293 k
 libgomp              x86_64 4.8.5-4.el7              HPCGRHEL7.2_updated 130 k
 libibumad            x86_64 1.3.10.2-1.3.10.2        IB_REPO              63 k
 libibverbs           x86_64 1.1.8-1                  IB_REPO              46 k
 libquadmath          x86_64 4.8.5-4.el7              HPCGRHEL7.2_updated 182 k
 librdmacm            x86_64 1.0.21-1                 IB_REPO              61 k
 mpi-selector         x86_64 1.0.3-1                  IB_REPO              24 k
 opensm-libs          x86_64 3.3.19-3.3.19            IB_REPO              60 k
 perl                 x86_64 4:5.16.3-286.el7         HPCGRHEL7.2_updated 8.0 M
 perl-Carp            noarch 1.26-244.el7             HPCGRHEL7.2_updated  19 k
 perl-Encode          x86_64 2.51-7.el7               HPCGRHEL7.2_updated 1.5 M
 perl-Exporter        noarch 5.68-3.el7               HPCGRHEL7.2_updated  28 k
 perl-File-Path       noarch 2.09-2.el7               HPCGRHEL7.2_updated  27 k
 perl-File-Temp       noarch 0.23.01-3.el7            HPCGRHEL7.2_updated  56 k
 perl-Filter          x86_64 1.49-3.el7               HPCGRHEL7.2_updated  76 k
 perl-Getopt-Long     noarch 2.40-2.el7               HPCGRHEL7.2_updated  56 k
 perl-HTTP-Tiny       noarch 0.033-3.el7              HPCGRHEL7.2_updated  38 k
 perl-PathTools       x86_64 3.40-5.el7               HPCGRHEL7.2_updated  83 k
 perl-Pod-Escapes     noarch 1:1.04-286.el7           HPCGRHEL7.2_updated  50 k
 perl-Pod-Perldoc     noarch 3.20-4.el7               HPCGRHEL7.2_updated  87 k
 perl-Pod-Simple      noarch 1:3.28-4.el7             HPCGRHEL7.2_updated 216 k
 perl-Pod-Usage       noarch 1.63-3.el7               HPCGRHEL7.2_updated  27 k
 perl-Scalar-List-Utils
                      x86_64 1.27-248.el7             HPCGRHEL7.2_updated  36 k
 perl-Socket          x86_64 2.010-3.el7              HPCGRHEL7.2_updated  49 k
 perl-Storable        x86_64 2.45-3.el7               HPCGRHEL7.2_updated  77 k
 perl-Text-ParseWords noarch 3.29-4.el7               HPCGRHEL7.2_updated  14 k
 perl-Time-HiRes      x86_64 4:1.9725-3.el7           HPCGRHEL7.2_updated  45 k
 perl-Time-Local      noarch 1.2300-2.el7             HPCGRHEL7.2_updated  24 k
 perl-constant        noarch 1.27-2.el7               HPCGRHEL7.2_updated  19 k
 perl-libs            x86_64 4:5.16.3-286.el7         HPCGRHEL7.2_updated 687 k
 perl-macros          x86_64 4:5.16.3-286.el7         HPCGRHEL7.2_updated  43 k
 perl-parent          noarch 1:0.225-244.el7          HPCGRHEL7.2_updated  12 k
 perl-podlators       noarch 2.5.1-3.el7              HPCGRHEL7.2_updated 112 k
 perl-threads         x86_64 1.87-4.el7               HPCGRHEL7.2_updated  49 k
 perl-threads-shared  x86_64 1.43-6.el7               HPCGRHEL7.2_updated  39 k
 tcsh                 x86_64 6.18.01-8.el7            HPCGRHEL7.2_updated 337 k

Transaction Summary
================================================================================
Install  4 Packages (+38 Dependent packages)

Total download size: 34 M
Installed size: 133 M
Downloading packages:
--------------------------------------------------------------------------------
Total                                               80 MB/s |  34 MB  00:00
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : libibverbs-1.1.8-1.x86_64                                   1/42
  Installing : librdmacm-1.0.21-1.x86_64                                   2/42
  Installing : libquadmath-4.8.5-4.el7.x86_64                              3/42
  Installing : libibumad-1.3.10.2-1.3.10.2.x86_64                          4/42
  Installing : opensm-libs-3.3.19-3.3.19.x86_64                            5/42
  Installing : mvapich2_gcc_qlc-2.1-1.x86_64                               6/42
/var/tmp/rpm-tmp.Pmp1b5: line 2: /usr/bin/mpi-selector: No such file or directory
warning: %post(mvapich2_gcc_qlc-2.1-1.x86_64) scriptlet failed, exit status 127
Non-fatal POSTIN scriptlet failure in rpm package mvapich2_gcc_qlc-2.1-1.x86_64
  Installing : libgfortran-4.8.5-4.el7.x86_64                              7/42
  Installing : libgomp-4.8.5-4.el7.x86_64                                  8/42
  Installing : tcsh-6.18.01-8.el7.x86_64                                   9/42
  Installing : groff-base-1.22.2-8.el7.x86_64                             10/42
  Installing : 1:perl-parent-0.225-244.el7.noarch                         11/42
  Installing : perl-HTTP-Tiny-0.033-3.el7.noarch                          12/42
  Installing : perl-podlators-2.5.1-3.el7.noarch                          13/42
  Installing : perl-Pod-Perldoc-3.20-4.el7.noarch                         14/42
  Installing : 1:perl-Pod-Escapes-1.04-286.el7.noarch                     15/42
  Installing : perl-Text-ParseWords-3.29-4.el7.noarch                     16/42
  Installing : perl-Encode-2.51-7.el7.x86_64                              17/42
  Installing : perl-Pod-Usage-1.63-3.el7.noarch                           18/42
  Installing : 4:perl-libs-5.16.3-286.el7.x86_64                          19/42
  Installing : 4:perl-macros-5.16.3-286.el7.x86_64                        20/42
  Installing : 4:perl-Time-HiRes-1.9725-3.el7.x86_64                      21/42
  Installing : perl-Exporter-5.68-3.el7.noarch                            22/42
  Installing : perl-constant-1.27-2.el7.noarch                            23/42
  Installing : perl-Time-Local-1.2300-2.el7.noarch                        24/42
  Installing : perl-Socket-2.010-3.el7.x86_64                             25/42
  Installing : perl-Storable-2.45-3.el7.x86_64                            26/42
  Installing : perl-PathTools-3.40-5.el7.x86_64                           27/42
  Installing : perl-Scalar-List-Utils-1.27-248.el7.x86_64                 28/42
  Installing : perl-File-Temp-0.23.01-3.el7.noarch                        29/42
  Installing : perl-File-Path-2.09-2.el7.noarch                           30/42
  Installing : perl-threads-shared-1.43-6.el7.x86_64                      31/42
  Installing : perl-threads-1.87-4.el7.x86_64                             32/42
  Installing : perl-Filter-1.49-3.el7.x86_64                              33/42
  Installing : perl-Carp-1.26-244.el7.noarch                              34/42
  Installing : 1:perl-Pod-Simple-3.28-4.el7.noarch                        35/42
  Installing : perl-Getopt-Long-2.40-2.el7.noarch                         36/42
  Installing : 4:perl-5.16.3-286.el7.x86_64                               37/42
  Installing : mpi-selector-1.0.3-1.x86_64                                38/42
  Installing : infinipath-libs-3.3-75029.1218_rhel7_qlc.x86_64            39/42
  Installing : openmpi_gcc_qlc-1.10.0-1.x86_64                            40/42
ERROR: Cannot read from source directory
       (/usr/mpi/gcc/openmpi-1.10.0-qlc/bin)
warning: %post(openmpi_gcc_qlc-1.10.0-1.x86_64) scriptlet failed, exit status 1
Non-fatal POSTIN scriptlet failure in rpm package openmpi_gcc_qlc-1.10.0-1.x86_64
  Installing : libipathverbs-1.3-1.x86_64                                 41/42
  Installing : hostname-3.13-3.el7.x86_64                                 42/42
  Verifying  : libibverbs-1.1.8-1.x86_64                                   1/42
  Verifying  : perl-HTTP-Tiny-0.033-3.el7.noarch                           2/42
  Verifying  : infinipath-libs-3.3-75029.1218_rhel7_qlc.x86_64             3/42
  Verifying  : perl-threads-shared-1.43-6.el7.x86_64                       4/42
  Verifying  : 4:perl-Time-HiRes-1.9725-3.el7.x86_64                       5/42
  Verifying  : perl-Exporter-5.68-3.el7.noarch                             6/42
  Verifying  : perl-constant-1.27-2.el7.noarch                             7/42
  Verifying  : perl-PathTools-3.40-5.el7.x86_64                            8/42
  Verifying  : 4:perl-libs-5.16.3-286.el7.x86_64                           9/42
  Verifying  : 4:perl-macros-5.16.3-286.el7.x86_64                        10/42
  Verifying  : 1:perl-parent-0.225-244.el7.noarch                         11/42
  Verifying  : opensm-libs-3.3.19-3.3.19.x86_64                           12/42
  Verifying  : 4:perl-5.16.3-286.el7.x86_64                               13/42
  Verifying  : groff-base-1.22.2-8.el7.x86_64                             14/42
  Verifying  : perl-File-Temp-0.23.01-3.el7.noarch                        15/42
  Verifying  : 1:perl-Pod-Simple-3.28-4.el7.noarch                        16/42
  Verifying  : tcsh-6.18.01-8.el7.x86_64                                  17/42
  Verifying  : perl-Time-Local-1.2300-2.el7.noarch                        18/42
  Verifying  : perl-Pod-Perldoc-3.20-4.el7.noarch                         19/42
  Verifying  : perl-Socket-2.010-3.el7.x86_64                             20/42
  Verifying  : mpi-selector-1.0.3-1.x86_64                                21/42
  Verifying  : libipathverbs-1.3-1.x86_64                                 22/42
  Verifying  : perl-podlators-2.5.1-3.el7.noarch                          23/42
  Verifying  : libgfortran-4.8.5-4.el7.x86_64                             24/42
  Verifying  : perl-Storable-2.45-3.el7.x86_64                            25/42
  Verifying  : perl-Scalar-List-Utils-1.27-248.el7.x86_64                 26/42
  Verifying  : 1:perl-Pod-Escapes-1.04-286.el7.noarch                     27/42
  Verifying  : perl-Pod-Usage-1.63-3.el7.noarch                           28/42
  Verifying  : hostname-3.13-3.el7.x86_64                                 29/42
  Verifying  : perl-Encode-2.51-7.el7.x86_64                              30/42
  Verifying  : libibumad-1.3.10.2-1.3.10.2.x86_64                         31/42
  Verifying  : perl-Getopt-Long-2.40-2.el7.noarch                         32/42
  Verifying  : perl-File-Path-2.09-2.el7.noarch                           33/42
  Verifying  : libgomp-4.8.5-4.el7.x86_64                                 34/42
  Verifying  : perl-threads-1.87-4.el7.x86_64                             35/42
  Verifying  : librdmacm-1.0.21-1.x86_64                                  36/42
  Verifying  : mvapich2_gcc_qlc-2.1-1.x86_64                              37/42
  Verifying  : libquadmath-4.8.5-4.el7.x86_64                             38/42
  Verifying  : perl-Filter-1.49-3.el7.x86_64                              39/42
  Verifying  : openmpi_gcc_qlc-1.10.0-1.x86_64                            40/42
  Verifying  : perl-Text-ParseWords-3.29-4.el7.noarch                     41/42
  Verifying  : perl-Carp-1.26-244.el7.noarch                              42/42

Installed:
  hostname.x86_64 0:3.13-3.el7          libipathverbs.x86_64 0:1.3-1
  mvapich2_gcc_qlc.x86_64 0:2.1-1       openmpi_gcc_qlc.x86_64 0:1.10.0-1

Dependency Installed:
  groff-base.x86_64 0:1.22.2-8.el7
  infinipath-libs.x86_64 0:3.3-75029.1218_rhel7_qlc
  libgfortran.x86_64 0:4.8.5-4.el7
  libgomp.x86_64 0:4.8.5-4.el7
  libibumad.x86_64 0:1.3.10.2-1.3.10.2
  libibverbs.x86_64 0:1.1.8-1
  libquadmath.x86_64 0:4.8.5-4.el7
  librdmacm.x86_64 0:1.0.21-1
  mpi-selector.x86_64 0:1.0.3-1
  opensm-libs.x86_64 0:3.3.19-3.3.19
  perl.x86_64 4:5.16.3-286.el7
  perl-Carp.noarch 0:1.26-244.el7
  perl-Encode.x86_64 0:2.51-7.el7
  perl-Exporter.noarch 0:5.68-3.el7
  perl-File-Path.noarch 0:2.09-2.el7
  perl-File-Temp.noarch 0:0.23.01-3.el7
  perl-Filter.x86_64 0:1.49-3.el7
  perl-Getopt-Long.noarch 0:2.40-2.el7
  perl-HTTP-Tiny.noarch 0:0.033-3.el7
  perl-PathTools.x86_64 0:3.40-5.el7
  perl-Pod-Escapes.noarch 1:1.04-286.el7
  perl-Pod-Perldoc.noarch 0:3.20-4.el7
  perl-Pod-Simple.noarch 1:3.28-4.el7
  perl-Pod-Usage.noarch 0:1.63-3.el7
  perl-Scalar-List-Utils.x86_64 0:1.27-248.el7
  perl-Socket.x86_64 0:2.010-3.el7
  perl-Storable.x86_64 0:2.45-3.el7
  perl-Text-ParseWords.noarch 0:3.29-4.el7
  perl-Time-HiRes.x86_64 4:1.9725-3.el7
  perl-Time-Local.noarch 0:1.2300-2.el7
  perl-constant.noarch 0:1.27-2.el7
  perl-libs.x86_64 4:5.16.3-286.el7
  perl-macros.x86_64 4:5.16.3-286.el7
  perl-parent.noarch 1:0.225-244.el7
  perl-podlators.noarch 0:2.5.1-3.el7
  perl-threads.x86_64 0:1.87-4.el7
  perl-threads-shared.x86_64 0:1.43-6.el7
  tcsh.x86_64 0:6.18.01-8.el7

Complete!
 ---> 5773002ff489
Removing intermediate container 37b2185e77cc
Step 7 : RUN yum -y erase openmpi_gcc_qlc mvapich2_gcc_qlc     #>>>>>>>>>>>>>>>>>>>>>>>>>>>> Because of a bug
 ---> Running in 8eba240ccf44
Loaded plugins: ovl, product-id, search-disabled-repos, subscription-manager
This system is not registered to Red Hat Subscription Management. You can use subscription-manager to register.
Resolving Dependencies
--> Running transaction check
---> Package mvapich2_gcc_qlc.x86_64 0:2.1-1 will be erased
---> Package openmpi_gcc_qlc.x86_64 0:1.10.0-1 will be erased
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package                 Arch          Version            Repository       Size
================================================================================
Removing:
 mvapich2_gcc_qlc        x86_64        2.1-1              @IB_REPO         17 M
 openmpi_gcc_qlc         x86_64        1.10.0-1           @IB_REPO         71 M

Transaction Summary
================================================================================
Remove  2 Packages

Installed size: 89 M
Downloading packages:
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
ERROR: Could not find openmpi_gcc_qlc-1.10.0 files registered
  Erasing    : openmpi_gcc_qlc-1.10.0-1.x86_64                              1/2
ERROR: Could not find mvapich2_gcc_qlc-2.1 files registered
  Erasing    : mvapich2_gcc_qlc-2.1-1.x86_64                                2/2
  Verifying  : mvapich2_gcc_qlc-2.1-1.x86_64                                1/2
  Verifying  : openmpi_gcc_qlc-1.10.0-1.x86_64                              2/2

Removed:
  mvapich2_gcc_qlc.x86_64 0:2.1-1       openmpi_gcc_qlc.x86_64 0:1.10.0-1

Complete!
 ---> dacf1bb43499
Removing intermediate container 8eba240ccf44
Step 8 : RUN rm -rf /usr/mpi/gcc/openmpi_gcc_qlc*
 ---> Running in 7bab81ab1069
 ---> 22527db86967
Removing intermediate container 7bab81ab1069
Step 9 : RUN rm -rf /usr/mpi/gcc/mvapich2_gcc_qlc*
 ---> Running in 27f1abb81a02
 ---> 327929e1b1ad
Removing intermediate container 27f1abb81a02
Step 10 : RUN yumdownloader mvapich2_gcc_qlc openmpi_gcc_qlc
 ---> Running in 4d1b8be3252c
Loaded plugins: ovl, product-id
 ---> a03022f3a83d
Removing intermediate container 4d1b8be3252c
Step 11 : RUN rpm -ivh mvapich2_gcc_qlc* openmpi_gcc_qlc*
 ---> Running in 6b4963973205
Preparing...                          ########################################
Updating / installing...
mvapich2_gcc_qlc-2.1-1                ########################################
openmpi_gcc_qlc-1.10.0-1              ########################################
 ---> 33706455a412
Removing intermediate container 6b4963973205
Step 12 : RUN yum -y install mpitests_openmpi_gcc_qlc mpitests_mvapich2_gcc_qlc
 ---> Running in 54df6cb06622
Loaded plugins: ovl, product-id, search-disabled-repos, subscription-manager
This system is not registered to Red Hat Subscription Management. You can use subscription-manager to register.
Resolving Dependencies
--> Running transaction check
---> Package mpitests_mvapich2_gcc_qlc.x86_64 0:3.2-923 will be installed
---> Package mpitests_openmpi_gcc_qlc.x86_64 0:3.2-923 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package                         Arch         Version       Repository     Size
================================================================================
Installing:
 mpitests_mvapich2_gcc_qlc       x86_64       3.2-923       IB_REPO        90 k
 mpitests_openmpi_gcc_qlc        x86_64       3.2-923       IB_REPO        93 k

Transaction Summary
================================================================================
Install  2 Packages

Total download size: 182 k
Installed size: 699 k
Downloading packages:
--------------------------------------------------------------------------------
Total                                              2.5 MB/s | 182 kB  00:00
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
Warning: RPMDB altered outside of yum.
  Installing : mpitests_mvapich2_gcc_qlc-3.2-923.x86_64                     1/2
  Installing : mpitests_openmpi_gcc_qlc-3.2-923.x86_64                      2/2
  Verifying  : mpitests_openmpi_gcc_qlc-3.2-923.x86_64                      1/2
  Verifying  : mpitests_mvapich2_gcc_qlc-3.2-923.x86_64                     2/2

Installed:
  mpitests_mvapich2_gcc_qlc.x86_64 0:3.2-923
  mpitests_openmpi_gcc_qlc.x86_64 0:3.2-923

Complete!
 ---> 85fcf80cc9c8
Removing intermediate container 54df6cb06622
Step 13 : RUN yum -y install openssh-clients
 ---> Running in 038a930c9af7
Loaded plugins: ovl, product-id, search-disabled-repos, subscription-manager
This system is not registered to Red Hat Subscription Management. You can use subscription-manager to register.
Resolving Dependencies
--> Running transaction check
---> Package openssh-clients.x86_64 0:6.6.1p1-25.el7_2 will be installed
--> Processing Dependency: openssh = 6.6.1p1-25.el7_2 for package: openssh-clients-6.6.1p1-25.el7_2.x86_64
--> Processing Dependency: fipscheck-lib(x86-64) >= 1.3.0 for package: openssh-clients-6.6.1p1-25.el7_2.x86_64
--> Processing Dependency: libfipscheck.so.1()(64bit) for package: openssh-clients-6.6.1p1-25.el7_2.x86_64
--> Processing Dependency: libedit.so.0()(64bit) for package: openssh-clients-6.6.1p1-25.el7_2.x86_64
--> Running transaction check
---> Package fipscheck-lib.x86_64 0:1.4.1-5.el7 will be installed
--> Processing Dependency: /usr/bin/fipscheck for package: fipscheck-lib-1.4.1-5.el7.x86_64
---> Package libedit.x86_64 0:3.0-12.20121213cvs.el7 will be installed
---> Package openssh.x86_64 0:6.6.1p1-25.el7_2 will be installed
--> Running transaction check
---> Package fipscheck.x86_64 0:1.4.1-5.el7 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package          Arch    Version                    Repository            Size
================================================================================
Installing:
 openssh-clients  x86_64  6.6.1p1-25.el7_2           HPCGRHEL7.2_updated  639 k
Installing for dependencies:
 fipscheck        x86_64  1.4.1-5.el7                HPCGRHEL7.2_updated   21 k
 fipscheck-lib    x86_64  1.4.1-5.el7                HPCGRHEL7.2_updated   11 k
 libedit          x86_64  3.0-12.20121213cvs.el7     HPCGRHEL7.2_updated   92 k
 openssh          x86_64  6.6.1p1-25.el7_2           HPCGRHEL7.2_updated  435 k

Transaction Summary
================================================================================
Install  1 Package (+4 Dependent packages)

Total download size: 1.2 M
Installed size: 3.9 M
Downloading packages:
--------------------------------------------------------------------------------
Total                                               11 MB/s | 1.2 MB  00:00
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : fipscheck-lib-1.4.1-5.el7.x86_64                             1/5
  Installing : fipscheck-1.4.1-5.el7.x86_64                                 2/5
  Installing : openssh-6.6.1p1-25.el7_2.x86_64                              3/5
  Installing : libedit-3.0-12.20121213cvs.el7.x86_64                        4/5
  Installing : openssh-clients-6.6.1p1-25.el7_2.x86_64                      5/5
  Verifying  : libedit-3.0-12.20121213cvs.el7.x86_64                        1/5
  Verifying  : openssh-6.6.1p1-25.el7_2.x86_64                              2/5
  Verifying  : openssh-clients-6.6.1p1-25.el7_2.x86_64                      3/5
  Verifying  : fipscheck-1.4.1-5.el7.x86_64                                 4/5
  Verifying  : fipscheck-lib-1.4.1-5.el7.x86_64                             5/5

Installed:
  openssh-clients.x86_64 0:6.6.1p1-25.el7_2

Dependency Installed:
  fipscheck.x86_64 0:1.4.1-5.el7            fipscheck-lib.x86_64 0:1.4.1-5.el7
  libedit.x86_64 0:3.0-12.20121213cvs.el7   openssh.x86_64 0:6.6.1p1-25.el7_2

Complete!
 ---> b58a1b32ceae
Removing intermediate container 038a930c9af7
Step 14 : RUN mv /usr/bin/ssh /usr/bin/ssh_real
 ---> Running in 9c3dbfc38cdb
 ---> 19ba209bc3f4
Removing intermediate container 9c3dbfc38cdb
Step 15 : ADD ssh-replacement.sh /usr/bin/ssh
 ---> bb0ec7d76ff2
Removing intermediate container bda1c503fe8a
Successfully built bb0ec7d76ff2

ahmed.bukhamsin@myserver21 ~/docker-ib-mpi] $ ./docker-mvapich2-mpirun -np 2 -hostfile ~/hostfile /usr/mpi/gcc/mvapich2-2.1-qlc/tests/osu_benchmarks-3.1.1/osu_latency D D
mpirun -np 2 -hostfile ~/hostfile /usr/mpi/gcc/mvapich2-2.1-qlc/tests/osu_benchmarks-3.1.1/osu_latency D D
# OSU MPI Latency Test v3.1.1
# Size            Latency (us)
0                         1.35
1                         1.36
2                         1.37
4                         1.36
8                         1.36
16                        1.57
32                        1.57
64                        1.57
128                       1.62
256                       1.75
512                       1.99
1024                      2.34
2048                      3.15
4096                      4.14
8192                      5.82
16384                    10.54
32768                    16.63
65536                    46.64
131072                   79.23
262144                  119.04
524288                  200.49
1048576                 362.68
2097152                 687.30
4194304                1335.89

</pre>
