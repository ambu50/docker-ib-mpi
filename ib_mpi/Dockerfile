# INFINIBAND support
# 05/12/2016

FROM myserver19:5000/rhel7
MAINTAINER Ahmed Bu-khamsin <ahmed.bukhamsin@aramco.com>


LABEL Description="Minimal RHEL7.2 with Infiniband and MPI support"
ADD ib_repo.repo /etc/yum.repos.d/
ADD RHEL7.2_updated.repo /etc/yum.repos.d/
RUN yum -y install libipathverbs openmpi_gcc_qlc mvapich2_gcc_qlc hostname
RUN yum -y erase openmpi_gcc_qlc mvapich2_gcc_qlc     #>>>>>>>>>>>>>>>>>>>>>>>>>>>> Because of a bug
RUN rm -rf /usr/mpi/gcc/openmpi_gcc_qlc*			
RUN rm -rf /usr/mpi/gcc/mvapich2_gcc_qlc*
RUN yumdownloader mvapich2_gcc_qlc openmpi_gcc_qlc
RUN rpm -ivh mvapich2_gcc_qlc* openmpi_gcc_qlc*
RUN yum -y install mpitests_openmpi_gcc_qlc mpitests_mvapich2_gcc_qlc
RUN yum -y install openssh-clients
RUN mv /usr/bin/ssh /usr/bin/ssh_real
ADD ssh-replacement.sh /usr/bin/ssh
RUN chmod 755 /usr/bin/ssh
RUN echo "* hard memlock unlimited" >> /etc/security/limits.conf
RUN echo "* soft memlock unlimited" >> /etc/security/limits.conf

