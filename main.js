module.exports = {
    apps: [
      {
        name: "hbs-backend",
        script: "bundle",
        args: "exec puma -C config/puma.rb -e production",
        cwd: "/home/deployer/www/hbs-backend/current",
        interpreter: "/bin/bash",
        env: {
          RAILS_ENV: "production"
        }
      }
    ]
  };
  