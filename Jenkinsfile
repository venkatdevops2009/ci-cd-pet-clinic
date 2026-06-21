pipeline {

    agent any

    options {
        ansiColor('xterm')
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform Action'
        )
    }

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'
    }

    stages {

        stage('Checkout Source') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                dir('Infra') {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds']
                    ]) {

                        sh '''
                        terraform init -reconfigure
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('Infra') {
                    sh '''
                    terraform fmt -check
                    terraform validate
                    '''
                }
            }
        }

        stage('Terraform Plan') {

            when {
                expression {
                    params.ACTION == "plan" || params.ACTION == "apply"
                }
            }

            steps {

                dir('Infra') {

                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds']
                    ]) {

                        sh '''
                        terraform plan -out=tfplan
                        '''

                        archiveArtifacts artifacts: 'tfplan'
                    }
                }
            }
        }

        stage('Terraform Apply') {

            when {
                expression {
                    params.ACTION == "apply"
                }
            }

            steps {

                input message: "Approve Terraform Apply?"

                dir('Infra') {

                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds']
                    ]) {

                        sh '''
                        terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }

        stage('Terraform Destroy') {

            when {
                expression {
                    params.ACTION == "destroy"
                }
            }

            steps {

                input message: "Destroy Infrastructure?"

                dir('Infra') {

                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds']
                    ]) {

                        sh '''
                        terraform destroy -auto-approve
                        '''
                    }
                }
            }
        }

        stage('Generate Ansible Inventory') {

            when {
                expression {
                    params.ACTION == "apply"
                }
            }

            steps {

                dir('Infra') {
                withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds']
                    ]) {

                    sh '''
                    JAVA_IP=$(terraform output -raw java_server_public_ip)
                    DB_IP=$(terraform output -raw db_server_private_ip)

                    cat > ../Ansible/inventory.ini <<EOF
[java_server]
$JAVA_IP ansible_user=ec2-user

[db_server]
$DB_IP ansible_user=ec2-user
EOF

                    echo "=============================="
                    echo "Generated Inventory"
                    echo "=============================="

                    cat ../Ansible/inventory.ini
                    '''
                   }
                }
           }
       }       

                stage('Ansible Connectivity Test') {
            when {
                expression { params.ACTION == "apply" }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'ec2-login',
                    usernameVariable: 'ANSIBLE_USER',
                    passwordVariable: 'ANSIBLE_PASS'
                )]) {
                    dir('Ansible') {
                        sh '''
                        ansible all \
                          -i inventory.ini \
                          -m ping \
                          -u $ANSIBLE_USER \
                          --extra-vars "ansible_password=$ANSIBLE_PASS"
                        '''
                    }
                }
            }
        }

        stage('Configure Database Server') {
            when {
                expression { params.ACTION == "apply" }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'ec2-login',
                    usernameVariable: 'ANSIBLE_USER',
                    passwordVariable: 'ANSIBLE_PASS'
                )]) {
                    retry(3) {
                        dir('Ansible') {
                            sh '''
                            ansible-playbook \
                              -i inventory.ini \
                              -u $ANSIBLE_USER \
                              --extra-vars "ansible_password=$ANSIBLE_PASS" \
                              db-server.yml
                            '''
                        }
                    }
                }
            }
        }

        stage('Configure Java Server') {
            when {
                expression { params.ACTION == "apply" }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'ec2-login',
                    usernameVariable: 'ANSIBLE_USER',
                    passwordVariable: 'ANSIBLE_PASS'
                )]) {
                    retry(3) {
                        dir('Ansible') {
                            sh '''
                            ansible-playbook \
                              -i inventory.ini \
                              -u $ANSIBLE_USER \
                              --extra-vars "ansible_password=$ANSIBLE_PASS" \
                              java-server.yml
                            '''
                        }
                    }
                }
            }
        }
        
    }

    post {

        success {
            echo 'Pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline failed.'
        }

        always {
            cleanWs()
        }
    }
}