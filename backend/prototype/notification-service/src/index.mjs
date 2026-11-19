/**
 * Notification Service (prototype)
 *
 * A stand-in for the first microservice extraction from the Auxilia backend:
 * reminder and notification delivery. It intentionally shares no code with
 * the monolith and speaks plain HTTP+JSON so the extraction boundary is
 * visible. NOT wired into docker-compose or render.yaml.
 *
 * Plain JavaScript with zero dependencies so it runs anywhere:
 *   node src/index.mjs
 *
 * Extraction path outlined in docs/microservices-prototype.md.
 */

import http from "node:http";

const port = Number(process.env.PORT ?? 3100);

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json");

  if (req.method === "GET" && req.url === "/health") {
    res.statusCode = 200;
    res.end(JSON.stringify({ status: "ok", service: "notification-service" }));
    return;
  }

  if (req.method === "POST" && req.url === "/notify") {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const payload = JSON.parse(body || "{}");
        // Prototype: log instead of sending email/push.
        console.log(
          JSON.stringify({ event: "notify.received", payload, at: new Date().toISOString() }),
        );
        res.statusCode = 202;
        res.end(JSON.stringify({ accepted: true }));
      } catch {
        res.statusCode = 400;
        res.end(JSON.stringify({ error: "invalid_json" }));
      }
    });
    return;
  }

  res.statusCode = 404;
  res.end(JSON.stringify({ error: "not_found" }));
});

server.listen(port, () => {
  console.log(`notification-service listening on :${port}`);
});
