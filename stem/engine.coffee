class Client
  @constructor: () ->
    @url = "https://api.github.com/repos/droub/keybox/contents/data%2fdb%2ejson"

  @getData: ( callback ) ->
    fetch( @url, {
      method: "GET",
      headers: {"Accept": "application/vnd.github.v3.raw+json"}
    })
    .then(response => response.json())
    .then(json => callback(json))
    .catch(err => alert(err))

  @getMeta: ( callback ) ->
    fetch( @url, {
      method: "GET",
      headers: {"Accept": "application/vnd.github.v3+json"}
    })
    .then(response => response.json())
    .then(json => callback(json))
    .catch(err => alert(err))

class Engine
    constructor: () ->
        @client = new Client()
        @client.getData (json) ->
          @vault = json.vault
          @door  = json.door
          @display() if @door is "open"

        # fetch "data/db.json"
        #   .then  (response) => response.json()
        #   .then  ( result ) =>
        #       @vault  = result.vault
        #       @door   = result.door
        #       @display() if @door is "open"
        #   .catch ( error  ) => throw error

    refresh: ( ) ->
      @vault.credentials=[]
      for entry in document.querySelectorAll(".entry")
          @vault.credentials.push {
            site : entry.querySelector(".site").innerHTML
            user : entry.querySelector(".user").innerHTML
            pass : entry.querySelector(".pass").innerHTML
            }
      @vault.note=document.querySelector("#note").innerHTML

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
        localStorage.setItem("masterkey",masterkey) # Remember masterkey
      else
        if @door is "close"
          alert "Sorry! Please enter a password"
          return null
      @display()

    save: ( detination ) ->
      @refresh()
      # AES encrypt
      masterkey = document.querySelector("#master").value
      if masterkey.length>0
        plaintext = JSON.stringify(@vault)
        encrypted = CryptoJS.AES.encrypt(plaintext, masterkey)
        encoded   = JSON.stringify({"door":"close","vault":btoa(encrypted)})
      else
        return null if not confirm "Saving in plain!"
        encoded   = JSON.stringify({"door":"open","vault":@vault})
        encoded   = encoded.replace(/},/g,"},\n")
        encoded   = encoded.replace(/],/g,"],\n")
        encoded   = encoded.replace(/:{/g,":\n{")
        encoded   = encoded.replace(/:\[/g,":\n[")
      # Remember masterkey
      localStorage.setItem("masterkey",masterkey)
      if destination is "dump"
        # Dump file
        a    = document.createElement "a"
        file = new Blob [encoded] , {type: 'application/json'}
        a.href = URL.createObjectURL(file);
        a.download = 'db.json'
        a.click()
      if destination is "github"
        console.log "Not yet available"

    add: () ->
      @vault.credentials=[] if not @vault.credentials?
      @vault.credentials.push {"site":"http","user":"user","pass":"password"}
      @display()

    remove: (index) ->
      @vault.credentials.splice(index,1)
      @display()

    display: () ->
      if @door is "open"
        pattern = new RegExp( document.querySelector("#filter").value )
        rows = []
        for entry,index in @vault.credentials
            if pattern.exec Object.values(entry).join("")
                rows.push "<tr class=\"entry\">"+
                  "<td class=\"icon\"><a onclick=\"engine.remove("+index+")\">x</a></td>"+
                  "<td class=\"site\" contenteditable oninput=\"engine.refresh()\">"+entry.site+"</td>"+
                  "<td class=\"user\" contenteditable oninput=\"engine.refresh()\">"+entry.user+"</td>"+
                  "<td class=\"pass\" contenteditable oninput=\"engine.refresh()\">"+entry.pass+"</td>"+
                  "</tr>"
        document.querySelector("#credentials").innerHTML = rows.join('')
        document.querySelector("#note").innerHTML = @vault.note

window.onload = () ->
  # remember the key
  if localStorage.masterkey?
    document.getElementById("master").defaultValue=localStorage.getItem("masterkey")
  window.engine = new Engine()
