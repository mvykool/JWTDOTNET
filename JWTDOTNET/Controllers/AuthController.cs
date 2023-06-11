using Microsoft.AspNetCore.Mvc;
using JWTDOTNET.Models;

namespace JWTDOTNET.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : Controller
    {
        public static User user = new User();
    }
}
