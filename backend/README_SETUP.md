# Auxilia Backend — Setup Guide

This is a starter scaffold for the missing backend files. It is designed for an Express + TypeScript API using MongoDB/Mongoose, Jest, Swagger, and Jenkins.

## Before you start

1. From the `backend` directory, check the existing `package.json` and install any missing packages:
   ```bash
   npm install express mongoose dotenv cors helmet
   npm install -D typescript ts-node-dev @types/node @types/express @types/cors jest ts-jest @types/jest supertest @types/supertest
   ```
2. Add the scripts below to `package.json` (merge them with your existing scripts; do not replace unrelated scripts):
   ```json
   {
     "scripts": {
       "dev": "ts-node-dev --respawn --transpile-only src/server.ts",
       "build": "tsc",
       "start": "node dist/server.js",
       "test": "jest --runInBand",
       "test:watch": "jest --watch"
     }
   }
   ```
3. Add a `.env.example` to your backend folder and copy it to `.env`. Fill in your own MongoDB connection string. Never commit `.env`.
4. Check `tsconfig.json` includes `src` and emits to `dist`.
5. Copy the folders/files in this scaffold into your existing `backend` directory. These files are additive; compare before overwriting any existing files.
6. Start MongoDB locally or configure a MongoDB Atlas database.
7. Run:
   ```bash
   npm run build
   npm test
   npm run dev
   ```
8. Open `http://localhost:3000/api-docs` for Swagger UI and `http://localhost:3000/health` for the health endpoint.

## Important

- This scaffold assumes your existing `src/app.ts`, `src/database.ts`, `src/server.ts`, and `src/swagger.ts` will be aligned with these files. Review those files before replacing anything.
- The sample task API is intentionally minimal. Add authentication, authorization, rate limiting, input schemas, and production-grade logging before handling real user data.
- The Jenkinsfile should run install, build, and tests. Configure Jenkins credentials and deployment only after the pipeline works locally.
