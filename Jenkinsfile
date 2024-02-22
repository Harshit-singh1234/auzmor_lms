@Library('k2glyph-shared@master') _
def deploy(String token, String imageTag, String apiUrl) {
    sh"""
      sh .env.sh>.env
      cat .env
    """
    container("docker") {
      withDockerRegistry(credentialsId: "${credentials_id}", url: "${docker_registry_url}") {
            sh "docker build --cache-from ${env.project_id}/${env.artifact}:latest --tag ${env.project_id}/${env.artifact}:latest ."
            sh "docker push ${env.project_id}/${env.artifact}:latest"
            sh "docker run --name lms-frontend --env token=$token --env apiUrl=$apiUrl --env project=$GCP_PROJECT -t ${env.project_id}/${env.artifact}:latest"
      }
    }
}
def deploy_s3(String bucket_name, String cloudfront_id){
   sh"""
    sh .env.sh>.env
    cat .env
  """
   container("docker") {
              withDockerRegistry(credentialsId: "${credentials_id}", url: "${docker_registry_url}") {
                String randomText = org.apache.commons.lang.RandomStringUtils.random(9, true, true)
                sh "docker build -f Dockerfile.new --cache-from ${env.project_id}/${env.artifact}:latest --tag ${env.project_id}/${env.artifact}:latest ."
                sh "docker push ${env.project_id}/${env.artifact}:latest"
                sh "docker run --name lms-frontend-${randomText} --env apiUrl=${env.REACT_APP_API_BASE_URL} -t ${env.project_id}/${env.artifact}:latest"
                sh "docker cp lms-frontend-${randomText}:/usr/src/app/build ./build && chown -R 1000:1000 ./build"
              }
              withAWS(credentials: 'AWS', region: 'us-east-2') {
                script {
                  def identity=awsIdentity();//Log AWS credentials
                  s3Upload(bucket:"$bucket_name", workingDir:'build', includePathPattern:'**/*');
                  s3Upload(bucket:"$bucket_name/.well-known", workingDir:".well-known", contentType:'application/json', acl:'PublicRead', includePathPattern:'**/*')
                  cfInvalidate(distribution:"$cloudfront_id", paths:['/*'], waitForCompletion: true)
                }
              }
              
          }
}
def changes
def imageTag=""
pipeline {
  agent {
        kubernetes {
          yaml """
            spec:
              affinity:
                nodeAffinity:
                  preferredDuringSchedulingIgnoredDuringExecution:
                  - weight: 1
                    preference:
                      matchExpressions:
                      - key: cloud.google.com/gke-preemptible
                        operator: In
                        values:
                        - "true"
              containers:
              - image: "docker:18.09-dind"
                name: "dind"
                args: 
                - "--insecure-registry=registry-docker-registry.registry.svc.cluster.local:5000"
                securityContext:
                  privileged: true
                volumeMounts:
                - mountPath: "/home/jenkins/agent"
                  name: "workspace-volume"
                  readOnly: false
              - command:
                - "cat"
                env:
                - name: "DOCKER_HOST"
                  value: "127.0.0.1"
                image: "docker:18.09"
                name: "docker"
                resources:
                  requests:
                    cpu: "3500m"
                    memory: "2500Mi"
                tty: true
                volumeMounts:
                - mountPath: "/home/jenkins/agent"
                  name: "workspace-volume"
                  readOnly: false
              - image: "jenkins/jnlp-slave:3.35-5-alpine"
                name: "jnlp"
                volumeMounts:
                - mountPath: "/home/jenkins/agent"
                  name: "workspace-volume"
                  readOnly: false
              nodeSelector:
                beta.kubernetes.io/os: "linux"
              restartPolicy: "Never"
              securityContext: {}
              volumes:
              - emptyDir:
                  medium: ""
                name: "workspace-volume"
 """
        }
  }
  options {
      buildDiscarder(logRotator(numToKeepStr:'10'))
      disableConcurrentBuilds()
      timeout(time: 30, unit: 'MINUTES')
  }
  environment {
        FIREBASE_INTEGRATION_TOKEN=credentials("FIREBASE_INTEGRATION_TOKEN")
        FIREBASE_DEV_TOKEN=credentials("FIREBASE_DEV_TOKEN")
        FIREBASE_PROD_TOKEN=credentials("FIREBASE_PROD_TOKEN")
        FIREBASE_STAGE_TOKEN=credentials("FIREBASE_STAGE_TOKEN")
        FIREBASE_LOAD_TOKEN=credentials("FIREBASE_LOAD_TOKEN")
        REACT_APP_UNSPLASH_APP_ID=credentials("REACT_APP_UNSPLASH_APP_ID")
        REACT_APP_UNSPLASH_SECRET=credentials("REACT_APP_UNSPLASH_SECRET")
        REACT_APP_ZENDESK_BASE_URL=credentials("REACT_APP_ZENDESK_BASE_URL")
        REACT_APP_ZENDESK_USERNAME=credentials("REACT_APP_ZENDESK_USERNAME")
        REACT_APP_ZENDESK_TOKEN=credentials("REACT_APP_ZENDESK_TOKEN")
        
        project_id="$registry_url/auzmor"
        artifact="lms-frontend"
        credentials_id="harbor-registry"
        docker_registry_url="http://$registry_url"
  }
  stages {
    stage('Check & Notify') {
      steps {
        script {
          changes=getChangeLog()
          def git_hash=sh returnStdout:true, script:'git rev-parse HEAD'
          def version="${git_hash.trim()}.${env.BUILD_NUMBER}"
          imageTag="${env.project_id}/${env.artifact}:${version}"
          sendNotificationUpdate status: "STARTED", email: 'false', channel: 'lms-frontend-deployment', changes: changes   
        }
        container("docker") {
            withDockerRegistry(credentialsId: "${credentials_id}", url: "${docker_registry_url}") {
              sh "docker pull ${env.project_id}/${env.artifact}:latest > /dev/null && echo \"exists\" || echo \"doesn't exists\""
            }
        }
      }
    }
    stage("PR Build Test") {
         when {
           not {
              anyOf {
                branch 'master';
                branch 'aws-master';
                branch 'staging';
                branch 'develop'
                branch 'integration'
                branch 'integration-v2'
                branch 'develop-v2';
                branch 'dev-v3';
              }
            }
        }
        steps {
            container("docker") {
                withDockerRegistry(credentialsId: "${credentials_id}", url: "${docker_registry_url}") {
                 sh "docker build --build-arg PR=true --cache-from ${env.project_id}/${env.artifact}:latest --tag ${env.project_id}/${env.artifact}:latest ."
                }
            }
        }
    }
    stage("Build & Deploy Dev") {
      when { branch 'develop' }
      environment {
            GCP_PROJECT="auzmor-lms-dev"
            REACT_APP_BASE_URL="https://learn-dev.auzmor.com/"
            REACT_APP_API_BASE_URL="https://learn-dev.api.auzmor.com/api/v1"
            REACT_APP_REALTIME_API_BASE_URL="https://rts-dev.auzmor.com/"
            REACT_APP_ENV="DEV"
            REACT_APP_GCP_STORAGE_BUCKET="lms-dev"
            REACT_APP_UNSPLASH_ACCESS_KEY="vlfLff4tVyaDbz7Ua3pdqClzPUgEl9pSsW_tP3XuXvM"
      }
      steps {
          deploy_s3("learn-frontend-develop","E1S0VL201W4TY2") 
      }
    }
    stage("Build & Deploy Integration") {
      when { branch 'integration' }
      environment {
            GCP_PROJECT="auzmor-lms-integration"
            REACT_APP_BASE_URL="https://learn-integration.auzmor.com/"
            REACT_APP_API_BASE_URL="https://learn-integration.api.auzmor.com/api/v1"
            REACT_APP_REALTIME_API_BASE_URL="https://rts-integration.auzmor.com/"
            REACT_APP_ENV="DEV"
            REACT_APP_GCP_STORAGE_BUCKET="lms-dev"
            REACT_APP_UNSPLASH_ACCESS_KEY="vlfLff4tVyaDbz7Ua3pdqClzPUgEl9pSsW_tP3XuXvM"
      }
      steps {
          deploy_s3("learn-frontend-integration","E11XNA9ZPC4XPQ") 
      }
    }
    stage("Build & Deploy Integration V2") {
      when { branch 'integration-v2' }
      environment {
            GCP_PROJECT="auzmor-lms-integration-v2"
            REACT_APP_BASE_URL="https://learn-integration-v2.auzmor.com/"
            REACT_APP_API_BASE_URL="https://learn-integration-v2.api.auzmor.com/api/v1"
            REACT_APP_ENV="DEV"
            REACT_APP_GCP_STORAGE_BUCKET="learn-integration-v2"
            REACT_APP_UNSPLASH_ACCESS_KEY="vlfLff4tVyaDbz7Ua3pdqClzPUgEl9pSsW_tP3XuXvM"
      }
      steps {
          deploy_s3("learn-frontend-integration-v2","E32S89MRC9MN8Y") 
      }
    }
    stage("Build & Deploy Develop V2") {
      when { branch 'develop-v2' }
      environment {
            GCP_PROJECT="auzmor-lms-dev-v2"
            REACT_APP_BASE_URL="https://learn-dev-v2.auzmor.com/"
            REACT_APP_API_BASE_URL="https://learn-dev-v2.api.auzmor.com/api/v1"
            REACT_APP_ENV="DEV"
            REACT_APP_GCP_STORAGE_BUCKET="learn-dev-v2"
            REACT_APP_UNSPLASH_ACCESS_KEY="vlfLff4tVyaDbz7Ua3pdqClzPUgEl9pSsW_tP3XuXvM"
      }
      steps {
        deploy_s3("learn-frontend-develop-v2","E1CFV30VGE87FG") 
      }
    }
    stage("Build & Deploy Staging V2") {
      when { branch 'staging-v2' }
      environment {
        GCP_PROJECT="auzmor-lms-staging-v2"
        REACT_APP_BASE_URL="https://learn-staging-v2.auzmor.com/"
        REACT_APP_API_BASE_URL="https://learn-staging-v2.api.auzmor.com/api/v1"
        REACT_APP_ENV="STAGING"
        REACT_APP_GCP_STORAGE_BUCKET="lms-staging"
        REACT_APP_UNSPLASH_ACCESS_KEY="vlfLff4tVyaDbz7Ua3pdqClzPUgEl9pSsW_tP3XuXvM"
      }
      steps {
          deploy_s3("learn-staging-v2","EQ5H6XX8CXAXU")
      }
    }
    stage("Build & Deploy Staging") {
      when { branch 'staging' }
      environment {
        GCP_PROJECT="auzmor-lms-staging"
        REACT_APP_BASE_URL="https://learn-staging.auzmor.com/"
        REACT_APP_API_BASE_URL="https://learn-staging.api.auzmor.com/api/v1"
        REACT_APP_ENV="STAGING"
        REACT_APP_GCP_STORAGE_BUCKET="lms-staging"
        REACT_APP_UNSPLASH_ACCESS_KEY="vlfLff4tVyaDbz7Ua3pdqClzPUgEl9pSsW_tP3XuXvM"
      }
      steps {
          deploy_s3("learn-frontend-staging","ETJO6IPKR0UCM")
      }
    }
    stage("Build & Deploy Sandbox") {
      when { branch 'master' }
      environment {
        GCP_PROJECT="auzmor-lms-sandbox"
        REACT_APP_BASE_URL="https://learn-sandbox.auzmor.com/"
        REACT_APP_API_BASE_URL="https://learn-sandbox.api.auzmor.com/api/v1"
        REACT_APP_ENV="SANDBOX"
        REACT_APP_GCP_STORAGE_BUCKET="lms-sandbox"
      }
      steps {
          deploy_s3("learn-sandbox-frontend","E1JRUDCXPJDCYF")
      }
    }
    stage("Manual Promotion AWs") {
        when {
            branch 'aws-master'
        }
        steps {
            milestone(1)
            sendNotificationUpdate status: "APPROVAL", email: 'false', channel: 'production-deployment-approval', changes: changes
            timeout(time: 10, unit: 'MINUTES') {
                input message: "Does Staging/ Sandbox look good?"
            }
            milestone(2)
        }
    }
    stage("Build & Deploy AWS Production") {
      when { branch 'aws-master' }
      environment {
         GCP_PROJECT="auzmor-lms"
         REACT_APP_BASE_URL="https://learn.auzmor.com/"
         REACT_APP_API_BASE_URL="https://learn.api.auzmor.com/api/v1"
         NODE_ENV="production"
         REACT_APP_ENV="PRODUCTION"
         REACT_APP_GCP_STORAGE_BUCKET="zulu-prod"
         REACT_APP_SMARTLOOK_KEY="378f06c43d61271f6c2b5ed2b8adfa1b32769d05"
         REACT_APP_UNSPLASH_ACCESS_KEY="vlfLff4tVyaDbz7Ua3pdqClzPUgEl9pSsW_tP3XuXvM"
      }
      steps {
        deploy_s3("learn-frontend-hosting","E22PQ5BZSAU778")
      }
    }
    stage("Manual Promotion") {
        when {
            branch 'master'
        }
        steps {
            milestone(1)
            sendNotificationUpdate status: "APPROVAL", email: 'false', channel: 'production-deployment-approval', changes: changes
            timeout(time: 10, unit: 'MINUTES') {
                input message: "Does Staging/ Sandbox look good?"
            }
            milestone(2)
        }
    }

    stage("Build & Deploy Production") {
      when { branch 'master' }
      environment {
         GCP_PROJECT="auzmor-lms"
         REACT_APP_BASE_URL="https://learn.auzmor.com/"
         REACT_APP_API_BASE_URL="https://learn.api.auzmor.com/api/v1"
         REACT_APP_ENV="PRODUCTION"
         REACT_APP_GCP_STORAGE_BUCKET="zulu-prod"
         REACT_APP_SMARTLOOK_KEY="378f06c43d61271f6c2b5ed2b8adfa1b32769d05"
      }
      steps {
        deploy_s3("learn-frontend-hosting","E22PQ5BZSAU778")           
      }
    }
  }
  post {
      success {
          sendNotificationUpdate status: "SUCCESS", email: 'false', channel: 'lms-frontend-deployment', changes: changes
      }
      failure {
          sendNotificationUpdate status: "FAILURE", email: 'false', channel: 'lms-frontend-deployment', changes: changes
      }
      aborted {
          sendNotificationUpdate status: "ABORTED", email: 'false', channel: 'lms-frontend-deployment', changes: changes
      }
  }
}