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
    }
}
