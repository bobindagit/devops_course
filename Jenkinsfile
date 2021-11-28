pipeline
{
    agent {
        label 'OneS'
    }
    
    environment {
        envString = 'true'
    }
 
    post {
        always {
            allure includeProperties: false, jdk: '', results: [[path: 'out/syntax-check/allure'], [path: 'out/allure/smoke'], [path: 'out/allure']]
            junit allowEmptyResults: true, testResults: 'out/syntax-check/junit/junit.xml'
            junit allowEmptyResults: true, testResults: 'out/*.xml'
        }
    
        failure {
            bat "echo failure"
        }
        
        success {
            bat "echo success"      
        }
    }
    stages {
        stage("Создание тестовой базы") {
            steps {
                bat "chcp 65001\n vrunner init-dev --dt C:\\Train_04_20\\Template\\course.dt --db-user Администратор --src src/cf"
 
            }
        }

    stage("Синтаксический контроль") {
            steps {
                bat "chcp 65001\n vrunner syntax-check"
 
            }
        }


    stage("Дымовые тесты") {
            steps {
                script{
                    try {
                        bat "chcp 65001\n runner xunit"
                    } catch(Exception Exc) {
                         currentBuild.result = 'UNSTABLE'
                    }
                }
 
            }
        }

    stage("vanessa") {
            steps {
                script{
                    try {
                        bat "chcp 65001\n runner vanessa"
                    } catch(Exception Exc) {
                         currentBuild.result = 'UNSTABLE'
                    }
                }
 
            }
        }

    stage("АПК") {
            steps {
                script{
                    try {
                        bat "chcp 65001\n runner run --ibconnection /FC:/Train_04_20/Template/ACC --db-user \"\" --db-pwd \"\"  --command \"acc.catalog=${WORKSPACE};acc.propertiesPaths=./tools/acc-export/acc.properties;\" --execute \"./tools/acc-export/acc-export.epf\" --ordinaryapp=1"
                    } catch(Exception Exc) {
                         currentBuild.result = 'UNSTABLE'
                    }
                }
 
            }
        }

    stage("Sonar") {
            steps {
                script{
                       scannerHome = tool 'sonar-scanner'
                }
            withSonarQubeEnv ("sonar") {
                    bat "${scannerHome}/bin/sonar-scanner -D sonar.login=b398eb45331f9fc123b352b4cf96d320cfeef8cd -D sonar.projectVersion=${BUILD_ID}"
                }  
            }
        }

    }
}
