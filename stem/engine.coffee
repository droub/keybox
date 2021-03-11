class Engine
    constructor: () ->
        # API back door for git commit
        @url = "https://api.github.com/repos/droub/keybox/contents/docs%2fdata%2fdb.json"
        # Initial load from the public page
        fetch "data/db.json"
            .then  (response) => response.json()
            .then  ( result ) =>
                @vault  = result.vault
                @door   = result.door
                @display() if @door is "open"
            .catch ( error  ) => throw error

    refresh: ( ) ->
        # read back the page to capture edits
        @vault.tokens=[]
        for entry in document.querySelectorAll("#tokens .entry")
            @vault.tokens.push {
                name  : entry.querySelector(".name" ).innerHTML
                value : entry.querySelector(".value").innerHTML
                }
        @vault.credentials=[]
        for entry in document.querySelectorAll("#credentials .entry")
            @vault.credentials.push {
                site : entry.querySelector(".site").innerHTML
                user : entry.querySelector(".user").innerHTML
                pass : entry.querySelector(".pass").innerHTML
                }
        @vault.note=document.querySelector("#note").value

    putData: ( content, token ) ->
        # github API
        fetch( @url, {
            method: "GET"
            headers:
              "Accept": "application/vnd.github.v3+json"
        })
        .then  ( response ) => response.json()
        .then  ( json ) =>
            fetch @url,
                method: "PUT"
                headers:
                    Accept: "application/vnd.github.v3+json"
                    Authorization: "token "+token
                body:
                    JSON.stringify
                        message: "pushed from browser"
                        branch: "main"
                        path: "docs/data/db.json"
                        sha: json.sha
                        content: btoa(content)

            .then  ( response ) =>
                if Object.keys(response.json()).length>0
                  alert JSON.stringify(response.json())
                else
                  alert "Commited!"
            .catch  ( err ) => alert "Fail!" +err
        .catch  ( err ) => alert "Fail!" +err

    open: ( ) ->
        # AES decrypt
        masterkey = document.querySelector("#master").value
        if masterkey.length>0 and @door is "close"
            try
                decoded   = atob(@vault)
                decrypted = CryptoJS.AES.decrypt(decoded, masterkey)
                _vault    = JSON.parse(decrypted.toString(CryptoJS.enc.Utf8))
            catch error
                alert "Sorry! Cant decrypt"
                return null
            @door   = "open"
            @vault  = _vault
            if document.getElementById("remember").checked
                localStorage.setItem("masterkey",masterkey)
        else
            if @door is "close"
                alert "Sorry! Please enter a password"
                return null
        @display()

    save: ( destination ) ->
        @refresh()
        # AES encrypt
        masterkey = document.querySelector("#master").value
        if masterkey.length>0
            plaintext = JSON.stringify(@vault)
            encrypted = CryptoJS.AES.encrypt(plaintext, masterkey)
            encoded   = JSON.stringify({"door":"close","vault":btoa(encrypted)})
        else
            if destination is "dump"
                return null if not confirm "Saving in plain!"
            else
                alert "Cannot upload in plain"
                return null
            encoded   = JSON.stringify({"door":"open","vault":@vault})
            encoded   = encoded.replace(/},/g,"},\n")
            encoded   = encoded.replace(/],/g,"],\n")
            encoded   = encoded.replace(/:{/g,":\n{")
            encoded   = encoded.replace(/:\[/g,":\n[")
            token     = "wrong"
        # Remember masterkey
        if document.getElementById("remember").checked
            localStorage.setItem("masterkey",masterkey)
        if destination is "dump"
            # Dump content in a file
            a    = document.createElement "a"
            file = new Blob [encoded] , {type: 'application/json'}
            a.href = URL.createObjectURL(file);
            a.download = 'db.json'
            a.click()
        if destination is "github"
            # Push content to git
            token = null
            for entry in @vault.tokens
              token=entry.value if entry.name is "keybox"
            if token
              @.putData( encoded , token )
            else
              alert 'First enter a "keybox" token'

    add: ( category ) ->
        @vault[category]=[] if not @vault[category]?
        if  category is "credentials"
            @vault[category].push {"site":"http","user":"user","pass":"password"}
        if  category is "tokens"
            @vault[category].push {"name":"mytoken","value":"myvalue"}
        @display()

    remove: (category,index) ->
        @vault[category].splice(index,1)
        @display()

    fold: ( button ) ->
        button.value = if button.value is "less" then "more" else "less"
        @display()

    display: () ->
        if @door is "open"
          pattern = new RegExp( document.querySelector("#filter").value )
          editable = 'contenteditable oninput="engine.refresh()"'
          rows = []
          for entry,index in @vault.tokens
              style = if pattern.exec Object.values(entry).join("") then "" else "display:none"
              rows.push "<tr class=\"entry\" style=\""+style+"\">"+
                  "<td class=\"icon\"><a onclick=\"engine.remove('tokens',"+index+")\">x</a></td>"+
                  "<td class=\"name\" "+editable+">"+entry.name+"</td>"+
                  "<td class=\"value\" "+editable+">"+entry.value+"</td>"+
                  "</tr>"
          if document.querySelector("#foldtokens").value is "less"
              document.querySelector("#tokens").style="display:initial"
          else
              document.querySelector("#tokens").style="display:none"
          document.querySelector("#tokens").innerHTML = rows.join('')
          rows = []
          for entry,index in @vault.credentials
              style = if pattern.exec Object.values(entry).join("") then "" else "display:none"
              rows.push "<tr class=\"entry\" style=\""+style+"\">"+
                  "<td class=\"icon\"><a onclick=\"engine.remove('credentials',"+index+")\">x</a></td>"+
                  "<td class=\"site\" "+editable+">"+entry.site+"</td>"+
                  "<td class=\"user\" "+editable+">"+entry.user+"</td>"+
                  "<td class=\"pass\" "+editable+">"+entry.pass+"</td>"+
                  "</tr>"
          document.querySelector("#credentials").innerHTML = rows.join('')
          if document.querySelector("#foldpass").value is "less"
              document.querySelector("#credentials").style="display:initial"
          else
              document.querySelector("#credentials").style="display:none"
          document.querySelector("#note").value = @vault.note

window.onload = () ->
  # remember the key
  if localStorage.masterkey?
    document.getElementById("master").defaultValue=localStorage.getItem("masterkey")
  window.engine = new Engine()
