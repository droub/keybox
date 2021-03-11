// Generated by CoffeeScript 2.5.0
var Engine;

Engine = class Engine {
  constructor() {
    // API back door for git commit
    this.url = "https://api.github.com/repos/droub/keybox/contents/docs%2fdata%2fdb.json";
    // Initial load from the public page
    fetch("data/db.json").then((response) => {
      return response.json();
    }).then((result) => {
      this.vault = result.vault;
      this.door = result.door;
      if (this.door === "open") {
        return this.display();
      }
    }).catch((error) => {
      throw error;
    });
  }

  refresh() {
    var entry, i, j, len, len1, ref, ref1;
    // read back the page to capture edits
    this.vault.tokens = [];
    ref = document.querySelectorAll("#tokens .entry");
    for (i = 0, len = ref.length; i < len; i++) {
      entry = ref[i];
      this.vault.tokens.push({
        name: entry.querySelector(".name").innerHTML,
        value: entry.querySelector(".value").innerHTML
      });
    }
    this.vault.credentials = [];
    ref1 = document.querySelectorAll("#credentials .entry");
    for (j = 0, len1 = ref1.length; j < len1; j++) {
      entry = ref1[j];
      this.vault.credentials.push({
        site: entry.querySelector(".site").innerHTML,
        user: entry.querySelector(".user").innerHTML,
        pass: entry.querySelector(".pass").innerHTML
      });
    }
    return this.vault.note = document.querySelector("#note").value;
  }

  putData(content, token) {
    // github API
    return fetch(this.url, {
      method: "GET",
      headers: {
        "Accept": "application/vnd.github.v3+json"
      }
    }).then((response) => {
      return response.json();
    }).then((json) => {
      return fetch(this.url, {
        method: "PUT",
        headers: {
          Accept: "application/vnd.github.v3+json",
          Authorization: "token " + token
        },
        body: JSON.stringify({
          message: "pushed from browser",
          branch: "main",
          path: "docs/data/db.json",
          sha: json.sha,
          content: btoa(content)
        })
      }).then((response) => {
        if (Object.keys(response.json()).length > 0) {
          return alert(JSON.stringify(response.json()));
        } else {
          return alert("Commited!");
        }
      }).catch((err) => {
        return alert("Fail!" + err);
      });
    }).catch((err) => {
      return alert("Fail!" + err);
    });
  }

  open() {
    var _vault, decoded, decrypted, error, masterkey;
    // AES decrypt
    masterkey = document.querySelector("#master").value;
    if (masterkey.length > 0 && this.door === "close") {
      try {
        decoded = atob(this.vault);
        decrypted = CryptoJS.AES.decrypt(decoded, masterkey);
        _vault = JSON.parse(decrypted.toString(CryptoJS.enc.Utf8));
      } catch (error1) {
        error = error1;
        alert("Sorry! Cant decrypt");
        return null;
      }
      this.door = "open";
      this.vault = _vault;
      if (document.getElementById("remember").checked) {
        localStorage.setItem("masterkey", masterkey);
      }
    } else {
      if (this.door === "close") {
        alert("Sorry! Please enter a password");
        return null;
      }
    }
    return this.display();
  }

  save(destination) {
    var a, encoded, encrypted, entry, file, i, len, masterkey, plaintext, ref, token;
    this.refresh();
    // AES encrypt
    masterkey = document.querySelector("#master").value;
    if (masterkey.length > 0) {
      plaintext = JSON.stringify(this.vault);
      encrypted = CryptoJS.AES.encrypt(plaintext, masterkey);
      encoded = JSON.stringify({
        "door": "close",
        "vault": btoa(encrypted)
      });
    } else {
      if (destination === "dump") {
        if (!confirm("Saving in plain!")) {
          return null;
        }
      } else {
        alert("Cannot upload in plain");
        return null;
      }
      encoded = JSON.stringify({
        "door": "open",
        "vault": this.vault
      });
      encoded = encoded.replace(/},/g, "},\n");
      encoded = encoded.replace(/],/g, "],\n");
      encoded = encoded.replace(/:{/g, ":\n{");
      encoded = encoded.replace(/:\[/g, ":\n[");
      token = "wrong";
    }
    // Remember masterkey
    if (document.getElementById("remember").checked) {
      localStorage.setItem("masterkey", masterkey);
    }
    if (destination === "dump") {
      // Dump content in a file
      a = document.createElement("a");
      file = new Blob([encoded], {
        type: 'application/json'
      });
      a.href = URL.createObjectURL(file);
      a.download = 'db.json';
      a.click();
    }
    if (destination === "github") {
      // Push content to git
      token = null;
      ref = this.vault.tokens;
      for (i = 0, len = ref.length; i < len; i++) {
        entry = ref[i];
        if (entry.name === "keybox") {
          token = entry.value;
        }
      }
      if (token) {
        return this.putData(encoded, token);
      } else {
        return alert('First enter a "keybox" token');
      }
    }
  }

  add(category) {
    if (this.vault[category] == null) {
      this.vault[category] = [];
    }
    if (category === "credentials") {
      this.vault[category].push({
        "site": "http",
        "user": "user",
        "pass": "password"
      });
    }
    if (category === "tokens") {
      this.vault[category].push({
        "name": "mytoken",
        "value": "myvalue"
      });
    }
    return this.display();
  }

  remove(category, index) {
    this.vault[category].splice(index, 1);
    return this.display();
  }

  fold(button) {
    button.value = button.value === "less" ? "more" : "less";
    return this.display();
  }

  display() {
    var editable, entry, i, index, j, len, len1, pattern, ref, ref1, rows, style;
    if (this.door === "open") {
      pattern = new RegExp(document.querySelector("#filter").value);
      editable = 'contenteditable oninput="engine.refresh()"';
      rows = [];
      ref = this.vault.tokens;
      for (index = i = 0, len = ref.length; i < len; index = ++i) {
        entry = ref[index];
        style = pattern.exec(Object.values(entry).join("")) ? "" : "display:none";
        rows.push("<tr class=\"entry\" style=\"" + style + "\">" + "<td class=\"icon\"><a onclick=\"engine.remove('tokens'," + index + ")\">x</a></td>" + "<td class=\"name\" " + editable + ">" + entry.name + "</td>" + "<td class=\"value\" " + editable + ">" + entry.value + "</td>" + "</tr>");
      }
      if (document.querySelector("#foldtokens").value === "less") {
        document.querySelector("#tokens").style = "display:initial";
      } else {
        document.querySelector("#tokens").style = "display:none";
      }
      document.querySelector("#tokens").innerHTML = rows.join('');
      rows = [];
      ref1 = this.vault.credentials;
      for (index = j = 0, len1 = ref1.length; j < len1; index = ++j) {
        entry = ref1[index];
        style = pattern.exec(Object.values(entry).join("")) ? "" : "display:none";
        rows.push("<tr class=\"entry\" style=\"" + style + "\">" + "<td class=\"icon\"><a onclick=\"engine.remove('credentials'," + index + ")\">x</a></td>" + "<td class=\"site\" " + editable + ">" + entry.site + "</td>" + "<td class=\"user\" " + editable + ">" + entry.user + "</td>" + "<td class=\"pass\" " + editable + ">" + entry.pass + "</td>" + "</tr>");
      }
      document.querySelector("#credentials").innerHTML = rows.join('');
      if (document.querySelector("#foldpass").value === "less") {
        document.querySelector("#credentials").style = "display:initial";
      } else {
        document.querySelector("#credentials").style = "display:none";
      }
      return document.querySelector("#note").value = this.vault.note;
    }
  }

};

window.onload = function() {
  // remember the key
  if (localStorage.masterkey != null) {
    document.getElementById("master").defaultValue = localStorage.getItem("masterkey");
  }
  return window.engine = new Engine();
};