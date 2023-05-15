let text = Deno.env.get("DATA");
let data;
data = JSON.parse(text,(k, v) => v === "true" ? true : v === "false" ? false : v);

try {
    const a = await Deno.resolveDns(data.host, "A");
    let istio_enabled=data.istio;
    if( istio_enabled!="")
    {
        if(istio_enabled)
        {
            const response = await fetch("http://localhost:15020/quitquitquit", {
              method: 'POST',
            });
        }
    }


}
catch (error){
    console.error("Could not resolve hostname")
    Deno.exit(1)
}