# Getting Started

1. Install VirtualBox
2. Install two Ubuntu Machines on the VirtualBox
3. Network the two Machines:Grok: Networking Linux VMs on VirtualBox
4. Clone a vsomeip Project : https://github.com/getgou/vsomeip#
5. Execute the hello World examples following the readme: https://github.com/COVESA/vsomeip/blob/master/examples/hello_world/readme
 Error: 1 Configuration module could not be loaded !
Solution: https://github.com/COVESA/vsomeip/issues/480
export LD_LIBRARY_PATH=/usr/local/lib in the ~/.bashrc file