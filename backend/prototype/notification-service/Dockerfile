# Notification Service (prototype/extraction candidate)
# Plain Node.js, zero dependencies.
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY --chown=node:node src ./src

USER node
EXPOSE 3100

CMD ["node", "src/index.mjs"]
