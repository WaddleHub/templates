// Preloaded (`node --require`) when scaffolding the website with create-next-app, which reads the
// current user's details from the system on start. The node container runs as your own user id,
// which has no entry in the container's user database, so that read fails. This answers it with
// the user id and home directory instead.
const os = require('node:os');
const userInfo = os.userInfo;

os.userInfo = (options) => {
  try {
    return userInfo(options);
  } catch {
    return {
      uid: process.getuid(),
      gid: process.getgid(),
      username: String(process.getuid()),
      homedir: os.homedir(),
      shell: null,
    };
  }
};
