#!/usr/bin/env groovy

String daily_cron_string = BRANCH_NAME == "master" ? "0 6 * * *" : ""

pipeline {
    agent {
        kubernetes {
            defaultContainer 'crops'
            yamlFile 'kubepods.yaml'
            workspaceVolume persistentVolumeClaimWorkspaceVolume(claimName: 'jenkins-workspace-claim', readOnly: false)
        }
    }

    triggers { cron(daily_cron_string) }

    stages {
        stage('Check') {
            steps{
                sh """
                     env
                     cat /etc/os-release
                     whoami
                     pwd
                     ls
                """
            }
        }
        stage('Setup layers') {
            steps{
                sh """ source poky/oe-init-build-env build
                       bitbake-layers add-layer ../meta-raspberrypi
                       bitbake-layers add-layer ../meta-raspberrypi
                       bitbake-layers add-layer ../meta-openembedded/meta-oe
                       bitbake-layers add-layer ../meta-openembedded/meta-python
                       bitbake-layers add-layer ../meta-openembedded/meta-networking
                       bitbake-layers add-layer ../meta-openembedded/meta-webserver
                       bitbake-layers add-layer ../meta-rauc
                       bitbake-layers add-layer ../meta-rauc-community/meta-rauc-raspberrypi
                       bitbake-layers add-layer ../meta-tinker
                       bitbake-layers add-layer ../meta-clang
                       bitbake-layers add-layer ../meta-browser/meta-chromium
                """
            }
        }
        stage('Create example keys') {
            steps{
                sh """ source poky/oe-init-build-env build
                       ../meta-rauc-community/create-example-keys.sh || true
                """
            }
        }
        stage('Build HomeSensorHub') {
            steps{
                sh """ source poky/oe-init-build-env build
                       export MACHINE=raspberrypi0-wifi
                       export DISTRO=poky-tinker
                       bitbake homesensorhub-image homesensorhub-bundle
                """
            }
        }
        stage('Build ControlCenter raspberrypi4-64') {
            steps{
                sh """ source poky/oe-init-build-env build
                       export MACHINE=raspberrypi4-64
                       export DISTRO=poky-tinker-gui
                       bitbake controlcenter-image controlcenter-bundle
                """
            }
        }
        stage('Build ControlCenter raspberrypi3-64') {
            steps{
                sh """ source poky/oe-init-build-env build
                       export MACHINE=raspberrypi3-64
                       export DISTRO=poky-tinker-gui
                       bitbake controlcenter-image controlcenter-bundle
                """
            }
        }
    }
}
