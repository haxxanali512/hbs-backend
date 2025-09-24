const { exec } = require('child_process');

// Ensure the correct environment is sourced first
exec('source /usr/local/rvm/scripts/rvm && bundle exec rails s -e production', (err, stdout, stderr) => {
  if (err) {
    console.log(`exec error: ${err}`);
    return;
  }
  console.log(`stdout: ${stdout}`);
  console.log(`stderr: ${stderr}`);
});
