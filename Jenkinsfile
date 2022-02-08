pipeline {
  /* run in any agent (a.k.a. node executor) */
  agent any

  stages {
    stage('Setup') {
      steps {
        script {
          /* Check the GIT_BRANCH to compute the target environment */
          if (env.GIT_BRANCH == 'origin/develop' || env.GIT_BRANCH ==~ /(.+)feature-(.+)/) {
            target = 'dev'
          } else if (env.GIT_BRANCH ==~ /(.+)release-(.+)/) {
            target = 'pre'
          } else if (env.GIT_BRANCH == 'origin/master') {
            target = 'prod'
          } else {
            error "Unknown branch type: ${env.GIT_BRANCH}"
          }

          /* Get the version from version manifest: src/package.yml */
          oversion    = sh(script: "jq -r '.variable.iac_version.default' src/package.yml", returnStdout: true).trim()

          /* Create the real version with Jenkins BUILD_NUMBER */
          version     = oversion.take(10) + '-' + env.BUILD_NUMBER
          oversion    = oversion.take(10)
          iacname     = env.JOB_NAME

          /* Your Project or Organization name */
          prjname     = 'oss-opensource'

          /* Create the package name with the real version */
          packname    = iacname + '-v' + version + '.tar.gz'

          /* Create the URL used to publish the package to Sonatype Nexus */
          publish_url = env.NEXUS_URL + '/repository/raw-terraform/' + prjname + '/' + packname
        }
      }
    }

    stage('Build'){
      steps {
        /* Inject the Build metadata in the inventory/build-vars.yml */
//        sh "sed -i 's/iac-provider/terraform/g' inventory/build-vars.yml"
//        sh "sed -i 's/iac-artifact/${packname}/g' inventory/build-vars.yml"
//        sh "sed -i 's/iac-scm-commit/${env.GIT_COMMIT}/g' inventory/build-vars.yml"
//        sh "sed -i 's|iac-scm-branch|${env.GIT_BRANCH}|g' inventory/build-vars.yml"
//        sh "sed -i 's/iac-build-by/jenkins/g' inventory/build-vars.yml"
//        sh "sed -i 's/iac-build-name/${env.JOB_NAME}/g' inventory/build-vars.yml"
//        sh "sed -i 's/iac-build-id/${env.BUILD_NUMBER}/g' inventory/build-vars.yml"
//        sh "sed -i 's/iac-build-date/${currentBuild.startTimeInMillis}/g' inventory/build-vars.yml"

        Map buildVars = [:]
        buildVars["iac-provider"]="terraform"
        buildVars["iac-artifact"]="${packname}"
        buildVars["iac-scm-commit"]="${env.GIT_COMMIT}"
        buildVars["iac-scm-branch"]="${env.GIT_BRANCH}"
        buildVars["iac-build-by"]="jenkins"
        buildVars["iac-build-name"]="${env.JOB_NAME}"
        buildVars["iac-build-id"]="${env.BUILD_NUMBER}"
        buildVars["iac-build-date"]="${currentBuild.startTimeInMillis}"

        /* Inject the real version, overwriting the original */
        sh "sed -i 's/${oversion}/${version}/g' src/package.yml"

        /* Create the package using a tar call */
        sh "tar --exclude='./.git' --exclude='./Jenkinsfile' --exclude='./resources' --exclude='*.tar.gz' -czv ./src -f " + packname
      }
    }

    stage('Publish'){
      steps {
        withCredentials([usernamePassword(credentialsId: 'nexus-credential', passwordVariable: 'NEXUS_PASSWORD', usernameVariable: 'NEXUS_USERNAME')]) {
          /* Publish to Sonatype Nexus using curl */
          sh 'curl -u $NEXUS_USERNAME:$NEXUS_PASSWORD --upload-file ' + packname + ' ' + publish_url
        }
      }
    }

    stage('DEV Deploy'){
      steps {
        withCredentials([usernamePassword(credentialsId: 'rundeck-credential', passwordVariable: 'RUNDECK_PASSWORD', usernameVariable: 'RUNDECK_USERNAME')]) {
          /*
           * Using a custom script to trigger and follow the rundeck job execution.
           * Get this script here: https://github.com/lj020326/cicd-paas-example/blob/master/resources/rundeck-exec-follow.sh
           * The custom script is saved in Jenkins using the Managed Script Plugin.
           */
          configFileProvider([configFile(fileId: 'rundeck-follow', variable: 'FOLLOW')]) {
            /*                job param      package url                rundeck job id              */
            sh 'bash $FOLLOW "artifact" "' + publish_url + '" "29cd3a68-e101-4176-907c-6fdf5bde13e7"'
          }
        }
      }
    }

    stage('PRE Deploy'){
      /* Just execute this stage when the targets are 'pre' or 'prod' */
      when {
        expression { return target == 'pre' || target == 'prod' }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'rundeck-credential', passwordVariable: 'RUNDECK_PASSWORD', usernameVariable: 'RUNDECK_USERNAME')]) {
          configFileProvider([configFile(fileId: 'rundeck-follow', variable: 'FOLLOW')]) {
            sh 'bash $FOLLOW "artifact" "' + publish_url + '" "ec0393b9-f0eb-4341-8812-eae241ef6544"'
          }
        }
      }
    }

    stage('Acceptance Test') {
      /* Just execute this stage when the target is 'prod' */
      when {
        expression { target == 'prod' }
      }

      /* Run the integrated tests in another agent */
      agent {
        label 'openshift_cli'
      }

      /* Use cucumber.js to perform the integrated tests */
      steps {
        sh 'cd test && npm install'
        sh 'cd test && npm test'

        /* Parse the report and generate the html reports */
        cucumber 'test/cucumber-report.json'
      }
    }

    stage('Approval') {
      when {
        expression { target == 'prod' }
      }
      steps {
        /* Wait 30 minutes to the user input, after this the pipeline will be aborted */
        timeout(time:30, unit:'MINUTES') {
          input message: "Deploy to Production?", id: "approval"
        }
      }
    }

    stage('PROD Deploy'){
      when {
        expression { return target == 'prod' }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'rundeck-credential', passwordVariable: 'RUNDECK_PASSWORD', usernameVariable: 'RUNDECK_USERNAME')]) {
          configFileProvider([configFile(fileId: 'rundeck-follow', variable: 'FOLLOW')]) {
            sh 'bash $FOLLOW "artifact" "' + publish_url + '" "f31fb4bb-4f55-4f23-9c03-784008acb5c4"'
          }
        }
      }
    }
  }

  /* Post pipeline execution, conditioned to pipeline status */
  post {
    success {
      /* Sends notification to Rocket.Chat */
      rocketSend attachments: [
        [
          audioUrl: '',
          authorIcon: '',
          authorName: '',
          color: 'green',
          imageUrl: '',
          messageLink: '',
          text: 'Success',
          thumbUrl: '',
          title: "${version}@${env.GIT_BRANCH}",
          titleLink: '',
          titleLinkDownload: '',
          videoUrl: ''
        ]
      ],
      avatar: "${env.WEBSERVER_URL}/static/jenkins.png",
      channel: 'oss-opensource',
      message: "Platform Build #${env.BUILD_NUMBER} finished - ${env.JOB_NAME} (<${env.BUILD_URL}|Open>)",
      rawMessage: true
    }

    failure {
      rocketSend attachments: [
        [
          audioUrl: '',
          authorIcon: '',
          authorName: '',
          color: 'red',
          imageUrl: '',
          messageLink: '',
          text: 'Failure',
          thumbUrl: '',
          title: "${version}@${env.GIT_BRANCH}",
          titleLink: '',
          titleLinkDownload: '',
          videoUrl: ''
        ]
      ],
      avatar: "${env.WEBSERVER_URL}/static/jenkins.png",
      channel: 'oss-opensource',
      message: "Platform Build #${env.BUILD_NUMBER} finished - ${env.JOB_NAME} (<${env.BUILD_URL}|Open>)",
      rawMessage: true
    }

    unstable {
      rocketSend attachments: [
        [
          audioUrl: '',
          authorIcon: '',
          authorName: '',
          color: 'yellow',
          imageUrl: '',
          messageLink: '',
          text: 'Unstable',
          thumbUrl: '',
          title: "${version}@${env.GIT_BRANCH}",
          titleLink: '',
          titleLinkDownload: '',
          videoUrl: ''
        ]
      ],
      avatar: "${env.WEBSERVER_URL}/static/jenkins.png",
      channel: 'oss-opensource',
      message: "Platform Build #${env.BUILD_NUMBER} finished - ${env.JOB_NAME} (<${env.BUILD_URL}|Open>)",
      rawMessage: true
    }

    aborted {
      rocketSend attachments: [
        [
          audioUrl: '',
          authorIcon: '',
          authorName: '',
          color: 'gray',
          imageUrl: '',
          messageLink: '',
          text: 'Aborted',
          thumbUrl: '',
          title: "${version}@${env.GIT_BRANCH}",
          titleLink: '',
          titleLinkDownload: '',
          videoUrl: ''
        ]
      ],
      avatar: "${env.WEBSERVER_URL}/static/jenkins.png",
      channel: 'oss-opensource',
      message: "Platform Build #${env.BUILD_NUMBER} finished - ${env.JOB_NAME} (<${env.BUILD_URL}|Open>)",
      rawMessage: true
    }
  }
}
