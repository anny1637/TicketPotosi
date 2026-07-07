<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Facades\Storage;

class AuthController extends Controller
{
    // REGISTRO
    public function register(Request $request)
    {
        $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|string|email|unique:users',
            'password' => 'required|string|min:6',
            'phone'    => 'nullable|string|max:20',
        ]);

        $user = User::create([
            'name'     => $request->name,
            'email'    => $request->email,
            'password' => Hash::make($request->password),
            'phone'    => $request->phone,
            'role_id'  => 2, // Cliente por defecto
            'status'   => 'active',
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Usuario registrado correctamente',
            'token'   => $token,
            'user'    => $user->load('role'),
        ], 201);
    }

    // LOGIN (con email O teléfono)
    public function login(Request $request)
    {
        $request->validate([
            'login'    => 'required|string', // puede ser email o teléfono
            'password' => 'required',
        ]);

        $login = $request->login;

        // Intentar buscar por email
        $user = User::where('email', $login)->first();

        // Si no encuentra por email, buscar por teléfono
        if (!$user) {
            $user = User::where('phone', $login)->first();
        }

        if (!$user || !Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'login' => ['Credenciales incorrectas. Verifica tu email/teléfono y contraseña.'],
            ]);
        }

        if ($user->status === 'inactive') {
            return response()->json([
                'message' => 'Tu cuenta está desactivada. Contacta al administrador.'
            ], 403);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Login exitoso',
            'token'   => $token,
            'user'    => $user->load('role'),
        ]);
    }

    // LOGOUT
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Sesión cerrada correctamente'
        ]);
    }

    // PERFIL
    public function profile(Request $request)
    {
        return response()->json($request->user()->load('role'));
    }

    // ACTUALIZAR PERFIL
    public function updateProfile(Request $request)
    {
        $request->validate([
            'name'  => 'sometimes|string|max:255',
            'phone' => 'sometimes|string|max:20',
            'photo' => 'nullable|file|image|max:5120',
        ]);

        $user = $request->user();
        $data = $request->only(['name', 'phone']);

        if ($request->hasFile('photo')) {
            if ($user->photo) {
                Storage::disk('public')->delete($user->photo);
            }
            $data['photo'] = $request->file('photo')->store('users/photos', 'public');
        }

        $user->update($data);

        return response()->json([
            'message' => 'Perfil actualizado',
            'user'    => $user->load('role'),
        ]);
    }

    // CAMBIAR CONTRASEÑA
    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required',
            'new_password'     => 'required|string|min:6',
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json(['message' => 'Contraseña actual incorrecta'], 422);
        }

        $user->update(['password' => Hash::make($request->new_password)]);

        return response()->json(['message' => 'Contraseña actualizada correctamente']);
    }

    // RECUPERAR CONTRASEÑA SIN TOKEN (PÚBLICO)
    public function resetPasswordWithoutToken(Request $request)
    {
        $request->validate([
            'email'        => 'required|email|exists:users,email',
            'phone'        => 'required|string',
            'new_password' => 'required|string|min:6',
        ]);

        $user = User::where('email', $request->email)
                    ->where('phone', $request->phone)
                    ->first();

        if (!$user) {
            return response()->json([
                'message' => 'El número de celular no coincide con el correo registrado.'
            ], 422);
        }

        $user->update(['password' => Hash::make($request->new_password)]);

        return response()->json([
            'message' => 'Contraseña restablecida correctamente. Ya puedes iniciar sesión.'
        ]);
    }
}