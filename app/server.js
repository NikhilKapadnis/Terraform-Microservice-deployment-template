const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

app.get("/", (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Name App</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            background: #f4f4f4;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
          }
          .card {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            width: 350px;
            text-align: center;
          }
          input {
            width: 90%;
            padding: 10px;
            margin: 15px 0;
          }
          button {
            padding: 10px 20px;
            cursor: pointer;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>What is your name?</h1>
          <form method="POST" action="/submit">
            <input type="text" name="name" placeholder="Enter your name" required />
            <br />
            <button type="submit">Submit</button>
          </form>
        </div>
      </body>
    </html>
  `);
});

app.post("/submit", (req, res) => {
  const name = req.body.name;

  // Later we will store this name in RDS MySQL.
  res.send(`
    <h1>Hello  , ${name}!</h1>
    <p>Your name will later be stored in RDS MySQL in next stages .</p>
    <a href="/">Go back</a>
  `);
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`App running on port ${PORT}`);
});