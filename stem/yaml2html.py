#!/usr/bin/env python
"""
Author : David Roubinet
Date   : Feb2021
Script :
    yaml-driven html generator with embeddable python logic

    Examples:                *.yaml > *.html

        div@here.center:            > <div id="here" class="center">
          - p: blabla               >   <p> blabla </p>
          - p: blabli               >   <p> blabli </p>
                                    > </div>

        python: rev="2.0"           >
        p:  The revision is {rev}   > <p> The revision is 2.0</p>

        python: |
          for X in range(3):        > <p> count: 0</p>
             inject_yaml(           > <p> count: 1</p>
                {"p": "count: {X}"} > <p> count: 2</p>
                )                   >

"""
import yaml
import json
import textwrap
import os.path
import re
import base64

def convert(filename,include_path,verbose):

    if verbose:
        print("Processing file:",filename)
        print("Include path:")
        for folder in include_path: print(" > ",folder)

    def search_file(arg):
        # Resolving the ordered include path
        filename=None
        for folder in include_path:
            if os.path.exists(folder+os.sep+arg):
                filename = f'{folder}{os.sep}{arg}'
                break
        if not filename:
            raise ValueError("Include file not found:",arg)
        return filename

    def encode_image(image):
        # Embedding of files as data-url
        filename=search_file(image)
        if verbose: print("Encoding:",filename)
        extension=filename.split(".")[-1]
        if extension in ["png","gif","jpg","svg"]:
            mediatype = {"png":"png","gif":"gif","jpg":"jpeg","svg":"svg+xml"}[extension]
            prefix  = f'data:image/{mediatype};base64,'
            payload = open(filename,'rb').read()
            dataurl =  prefix + base64.b64encode(payload).decode('utf-8')
            return dataurl
        else:
            raise ValueError("Image format not supported",extension)

    def inject_image(image,width="200px",height="auto"):
        dataurl=encode_image(image)
        doc.append(f'<img width="{width}" height="{height}" src="{dataurl}"/>')

    def inject_json(variable,filename):
        filename=search_file(filename)
        db=json.load(open(filename))
        doc.append(f"var {variable}="+json.dumps(db)+";")

    def inject_yaml(arg):
        # Expecting a yaml-like object
        walk(arg,level=level,tag="injected")

    def inject_html(arg):
        # Expecting html to be substituted with variables
        tag_body("injected",arg)

    def inject_asis(arg):
        # Expecting html
        doc.append(arg)

    def resolve(txt,wiki=True):
        # Substition is based on standard string interpolation
        txt= eval(f'f"""{txt}"""',context)
        txt= txt.rstrip()
        if wiki:
            txt=re.sub(r'_\=(.+?)\=_',r'<code>\1</code>',txt)
            txt=re.sub(r'_\*(.+?)\*_\.(\S+)',r'<span class="\2">\1</span>',txt)
            txt=re.sub(r'_\*(.+?)\*_',r'<b>\1</b>',txt)
        return txt

    def anchor():
        # Creates unique identifiers for title linking from toc
        return f'idtoc_{toc["n2"]}_{toc["n3"]}_{toc["n4"]}'

    def tag_open(tag,attributes,level):
        # Writes the <tagname att1=val1 att2=val2> part
        #print("open",tag,attributes)
        if tag not in ["python","if"]:
            classes=[]
            if "." in tag:
                chunks = tag.split(".")
                tag = chunks[0]
                for chunk in chunks[1:]:
                    if "=" in chunk:
                        name,value=chunk.split("=")
                        if name in attributes:
                            raise ValueError("Multiple attribute assignment",tag,name)
                        attributes[name]=value
                    else:
                        classes.append(chunk)
            if len(classes)>0:
                if "class" not in attributes:
                    attributes["class"]=""
                attributes["class"]+=" "+" ".join(classes)
            if tag in ["h2","h3","h4"]:
                if tag=="h2": toc["n2"]+=1; toc["n3"]=0; toc["n4"]=0
                if tag=="h3": toc["n3"]+=1; toc["n4"]=0
                if tag=="h4": toc["n4"]+=1
                if "id" in attributes:
                    print("Warning! id attribute of titles are ignored:",
                            attributes["id"])
                attributes["id"]=anchor()

            html=" "*level
            if tag=="doctype": tag="!DOCTYPE"
            if tag=="table":
                if "id" in attributes and attributes["id"]=="toc":
                    toc["enable"]=True
            if tag=="div" and "class" in attributes:
                if "page" in attributes["class"]:
                    toc["page"]+=1
            html+=f"<{tag}"
            for key in attributes:
                if type(attributes[key])==bool:
                    if attributes[key]: html+=f" {key}"
                    else: pass # Absence of Boolean attribute = false in html
                elif type(attributes[key])==dict:
                    if "python" in attributes[key]:
                        html+=f' {key}="{eval(attributes[key]["python"],context)}"'
                    else:
                        raise ValueError("Attribute too complex to be supported",tag,key)
                else:
                    # print(key,attributes[key])
                    html+=f' {key}="{str(attributes[key]).strip()}"'
            html += ">"
            html = resolve(html)
            doc.append(html)

    def tag_close(tag,level):
        # Writes the </tagname> part
        if "." in tag: tag=tag[:tag.index(".")]
        if tag=="body":
            if toc["enable"]:
                doc.append('<script>')
                doc.append('var toc=document.getElementById("toc");')
                for row in toc["rows"]:
                    doc.append(f"toc.innerHTML+='{row}'")
                doc.append("</script>")
        html=" "*level
        html+=f"</{tag}>"
        if tag not in ["python","doctype"]:
            doc.append(html)

    def tag_body(tag,txt):
        # Writes the textual content part or execute run-time scripts
        txt=textwrap.dedent(str(txt))
        txt=txt.strip()
        if tag not in ["python","if"]:
            if tag not in ["script","style"]:
                txt=resolve(txt)
            if tag in ["h2","h3","h4"]:
                if "numbered_headings" in context and context["numbered_headings"]:
                    if tag=="h2": txt=f'{toc["n2"]}. {txt}'
                    if tag=="h3": txt=f'{toc["n2"]}.{toc["n3"]} {txt}'
                    if tag=="h4": txt=f'{toc["n2"]}.{toc["n3"]}.{toc["n4"]} {txt}'
                entry  ='<tr><td class="toc_'+tag+'">'
                entry +=f'<a href="#{anchor()}">{txt}</a>'
                entry +=f'</td><td>page {toc["page"]}</td></tr>'
                toc["rows"].append(entry)
            doc.append(txt)
        else:
            try: exec(txt,context)
            except:
                print(txt)
                raise SystemError

    def walk(node,level=0,tag=""):
        # Recursive parsing of the yaml structure
        if   type(node) in [str,int,float]: tag_body(tag,node)
        elif type(node)==dict:
            for key in node:
                if key=="include":
                    filename=search_file(node[key])
                    if verbose:
                        print("Including:",filename)
                    walk(yaml.full_load(open(filename,encoding='utf-8')),level,tag)
                elif key=="inject":
                    filename=search_file(node[key])
                    if verbose:
                        print("Injecting:",filename)
                    inject_asis(open(filename,encoding='utf-8').read())
                else:
                    attributes = {}
                    if type(node[key])==dict:
                        if "attributes" in node[key]:
                            attributes=node[key].pop("attributes")
                        if "content" in node[key]:
                            node[key]=node[key]["content"]
                    tag=key
                    if tag.split(".")[0]=="math":
                        tag=tag.replace("math","div")
                        tag_open(tag,attributes,level)
                        inject_asis("\[ "+node[key]+" \]")
                        tag_close(tag,level)
                    else:
                        tag_open(tag,attributes,level)
                        walk(node[key], level+1,tag)
                        tag_close(tag,level)
        elif type(node)==list:
            for val in node:
                walk(val, level,tag)

    # global list of resulting html slices
    doc=[]
    toc={"n2":0,"n3":0,"n4":0,"enable":False,"rows":[],"page":0}
    # variables and functions accessible by the document-embedded python
    context={"doc":doc,
            "encode_image":encode_image,
            "inject_image":inject_image,
            "inject_json":inject_json,
            "inject_html":inject_html,
            "inject_yaml":inject_yaml,
            "inject_asis":inject_asis}
    # do the job
    walk({"include":filename})
    return "\n".join(doc)

if __name__=="__main__":
    import argparse
    parser = argparse.ArgumentParser(
    formatter_class=argparse.RawDescriptionHelpFormatter,
    description=textwrap.dedent(__doc__))
    parser.add_argument('src',help="Input YAML File")
    parser.add_argument('dst',help="Output directory")
    parser.add_argument('-v',help="Verbose",action='store_true')
    args = vars(parser.parse_args())
    include_path=[]
    include_path.append( os.getcwd())
    include_path.append( os.getcwd()+os.sep+os.path.dirname( args['src'] ))
    include_path.append( os.path.dirname( os.path.abspath(__file__)    ))
    html = convert(os.path.basename(args["src"]),include_path,args["v"])
    filename = args["dst"] +os.sep \
              +os.path.basename(args["src"]).split(".")[-2] \
              +".html"
    print("Creating:",filename)
    fo=open(filename,"w",encoding="utf-8")
    fo.write(html)
    fo.close()
