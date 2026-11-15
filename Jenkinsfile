/*
 * File Name: Jenkinsfile
 * Description: Defines the Jenkins CI/CD pipeline for the Auxilia project
 *              (backend API + Flutter web frontend).
 * Author: Keefe Chen
 * Date: 13 November 2026
 *
 * What it does, in order:
 *   1. Checks out the repository (Jenkins "Pipeline script from SCM" job).
 *   2. Backend  : npm ci -> lint + typecheck -> tests with coverage -> build.
 *   3. Frontend : flutter pub get -> format check -> analyze -> tests with
 *                 coverage -> 60% line-coverage gate -> web release build.
 *   4. Deploy   : rebuilds and restarts the local Docker Compose stack
 *                 (mongo + API + Flutter web), then waits for health checks.
 *                 Requires the host Docker socket (see docker-compose.yml and
 *                 docs/development/jenkins.md) and runs on the `main` branch,
 *                 or when the DEPLOY parameter is ticked. Asks for approval
 *                 first.
 *
 * Prerequisites on the Jenkins agent: Node.js 22, Flutter 3.47.8 and the
 * Docker CLI — all pre-installed by jenkins/Dockerfile.
 *
 * This pipeline mirrors .github/workflows/ci.yml. GitHub Actions remains the
 * remote quality gate; Jenkins runs the same gate locally and performs the
 * local redeploy.
 */

pipeline {

    /*
     * Runs on the all-in-one local Jenkins container, which has Node.js,
     * Flutter and the Docker CLI baked in (see jenkins/Dockerfile).
     */
    agent any

    options {
        // Prefix every log line with an RFC 3339 timestamp.
        timestamps()
        // Never run two builds of the same job at once (the deploy stage
        // mutates the shared local stack).
        disableConcurrentBuilds()
        // Keep the last 20 builds; discard their history beyond that.
        buildDiscarder(logRotator(numToKeepStr: '20'))
        // Safety net so a hung download does not hold the executor forever.
        timeout(time: 60, unit: 'MINUTES')
    }

    parameters {
        booleanParam(
            name: 'DEPLOY',
            defaultValue: false,
            description: 'Redeploy the local Docker Compose stack after the quality gate passes'
        )
    }

    /*
     * Uncomment to poll GitHub every minute instead of using a webhook
     * (a public URL such as ngrok is needed for webhooks):
     * triggers { pollSCM('* * * * *') }
     */

    environment {
        // Marks the run as CI so tooling picks non-interactive defaults.
        CI = 'true'
    }

    stages {

        /*
         * Stage 1: Checkout
         * Jenkins clones the repository and branch configured on the job
         * (Pipeline script from SCM). `checkout scm` reuses that job config.
         */
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        /*
         * Stage 2: Backend quality gate
         * Same steps as the `backend` job in .github/workflows/ci.yml,
         * minus the npm audit and the format check that need PR refs.
         */
        stage('Backend') {
            stages {

                stage('Install Dependencies') {
                    steps {
                        // npm ci installs exactly what package-lock.json pins.
                        dir('backend') {
                            sh 'npm ci --ignore-scripts'
                        }
                    }
                }

                stage('Lint and Type Check') {
                    steps {
                        // npm run lint = tsc --noEmit + eslint src tests
                        dir('backend') {
                            sh 'npm run lint'
                        }
                    }
                }

                stage('Automated Tests') {
                    steps {
                        // Vitest with the v8 coverage ratchet enforced in
                        // backend/vitest.config.mts.
                        dir('backend') {
                            sh 'npm run test:coverage'
                        }
                    }
                }

                stage('Build') {
                    steps {
                        // Compiles TypeScript to backend/dist.
                        dir('backend') {
                            sh 'npm run build'
                        }
                    }
                }
            }
        }

        /*
         * Stage 3: Frontend quality gate
         * Same steps as the `frontend` job in .github/workflows/ci.yml.
         */
        stage('Frontend') {
            stages {

                stage('Install Dependencies') {
                    steps {
                        dir('frontend') {
                            sh 'flutter pub get --enforce-lockfile'
                        }
                    }
                }

                stage('Format Check') {
                    steps {
                        // Fails the build if any file is not dart-formatted.
                        dir('frontend') {
                            sh 'dart format --output=none --set-exit-if-changed lib test tool integration_test'
                        }
                    }
                }

                stage('Static Analysis') {
                    steps {
                        // --no-fatal-infos keeps pre-existing style lints
                        // non-fatal, matching GitHub Actions.
                        dir('frontend') {
                            sh 'flutter analyze --no-fatal-infos'
                        }
                    }
                }

                stage('Automated Tests') {
                    steps {
                        dir('frontend') {
                            sh 'flutter test --coverage'
                        }
                    }
                }

                stage('Coverage Gate (60%)') {
                    steps {
                        // Fails below the 60% line-coverage threshold.
                        dir('frontend') {
                            sh 'dart run tool/check_coverage.dart 60'
                        }
                    }
                }

                stage('Build Web') {
                    steps {
                        // Produces frontend/build/web, which the Nginx
                        // container serves.
                        dir('frontend') {
                            sh 'flutter build web --release'
                        }
                    }
                }
            }
        }

        /*
         * Stage 4: Deploy the local stack
         * Skipped unless the build runs off `main`/`master`, or the DEPLOY
         * parameter is ticked. Asks for manual approval before touching the
         * running stack. Builds the same images CI's e2e job uses, restarts
         * the stack, then waits for the backend health check.
         */
        stage('Deploy (Local)') {
            when {
                expression {
                    return (params.DEPLOY ?: false) || ['main', 'master'].contains(env.BRANCH_NAME)
                }
            }
            steps {
                input message: 'Rebuild and restart the local stack?', ok: 'Deploy'

                sh 'docker compose build'
                sh 'docker compose up -d'

                // Wait for mongo -> backend -> frontend to become healthy.
                sh '''
                    set -e
                    for attempt in $(seq 1 90); do
                      if curl -fsS http://127.0.0.1:3000/api/health > /dev/null 2>&1 \
                      && curl -fsS http://127.0.0.1:8080/ > /dev/null 2>&1; then
                        echo "Stack is healthy after $((attempt * 2))s."
                        exit 0
                      fi
                      sleep 2
                    done
                    echo "Stack did not become healthy in time."
                    docker compose ps
                    docker compose logs --tail=100
                    exit 1
                '''
            }
        }
    }

    /*
     * Post-build actions run after the stages finish.
     */
    post {
        success {
            echo 'Auxilia pipeline passed: backend and frontend quality gates are green.'
        }
        failure {
            echo 'Auxilia pipeline failed. Open the stage logs above to see which gate failed.'
        }
        always {
            // Keep build output and coverage reports as downloadable
            // artifacts (Actions tab / build page, last 20 builds).
            archiveArtifacts(
                artifacts: 'backend/dist/**, backend/coverage/**, frontend/build/web/**, frontend/coverage/**',
                allowEmptyArchive: true,
                fingerprint: false
            )
            echo 'CI pipeline execution has finished.'
        }
    }
}
